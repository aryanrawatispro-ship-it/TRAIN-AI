package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"syscall"
	"time"

	"github.com/shirou/gopsutil/v3/gpu"
	"github.com/shirou/gopsutil/v3/mem"
)

// Config holds agent configuration
type Config struct {
	NodeID       string
	NodeName     string
	APIBaseURL   string
	MTLSCertPath string
	MTLSKeyPath  string
	PollInterval time.Duration
	HeartbeatInterval time.Duration
}

// GPUInfo represents GPU hardware information
type GPUInfo struct {
	Count        int    `json:"count"`
	Model        string `json:"model"`
	VRAMTotalMB  int    `json:"vram_total_mb"`
	VRAMFreeMB   int    `json:"vram_free_mb"`
	Utilization  int    `json:"utilization_percent"`
	Temperature  int    `json:"temperature_c"`
}

// Job represents a training job
type Job struct {
	JobID       string                 `json:"job_id"`
	DockerImage string                 `json:"docker_image"`
	Config      map[string]interface{} `json:"config"`
	Secrets     map[string]string      `json:"secrets"`
}

// Agent represents the BYO GPU agent
type Agent struct {
	config     Config
	httpClient *http.Client
	currentJob *Job
	ctx        context.Context
	cancel     context.CancelFunc
}

// NewAgent creates a new agent instance
func NewAgent(cfg Config) (*Agent, error) {
	cert, err := tls.LoadX509KeyPair(cfg.MTLSCertPath, cfg.MTLSKeyPath)
	if err != nil {
		return nil, fmt.Errorf("failed to load mTLS certificates: %w", err)
	}

	tlsConfig := &tls.Config{
		Certificates: []tls.Certificate{cert},
		MinVersion:   tls.VersionTLS13,
	}

	httpClient := &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: tlsConfig,
		},
		Timeout: 30 * time.Second,
	}

	ctx, cancel := context.WithCancel(context.Background())

	return &Agent{
		config:     cfg,
		httpClient: httpClient,
		ctx:        ctx,
		cancel:     cancel,
	}, nil
}

// Start starts the agent main loop
func (a *Agent) Start() error {
	log.Printf("Starting GPU Agent %s (Node: %s)", a.config.NodeID, a.config.NodeName)

	// Start heartbeat goroutine
	go a.heartbeatLoop()

	// Start job polling loop
	go a.jobPollingLoop()

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	<-sigChan

	log.Println("Shutdown signal received, stopping agent...")
	a.Shutdown()

	return nil
}

// Shutdown gracefully shuts down the agent
func (a *Agent) Shutdown() {
	a.cancel()

	// Wait for current job to finish (with timeout)
	if a.currentJob != nil {
		log.Printf("Waiting for current job %s to complete...", a.currentJob.JobID)
		time.Sleep(5 * time.Second) // Grace period
	}

	log.Println("Agent stopped")
}

// heartbeatLoop sends periodic heartbeats
func (a *Agent) heartbeatLoop() {
	ticker := time.NewTicker(a.config.HeartbeatInterval)
	defer ticker.Stop()

	for {
		select {
		case <-a.ctx.Done():
			return
		case <-ticker.C:
			if err := a.sendHeartbeat(); err != nil {
				log.Printf("Heartbeat failed: %v", err)
			}
		}
	}
}

// sendHeartbeat sends a heartbeat to the API
func (a *Agent) sendHeartbeat() error {
	gpuInfo, err := a.getGPUInfo()
	if err != nil {
		return fmt.Errorf("failed to get GPU info: %w", err)
	}

	status := "ONLINE"
	if a.currentJob != nil {
		status = "BUSY"
	}

	payload := map[string]interface{}{
		"status":   status,
		"gpu_info": gpuInfo,
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	url := fmt.Sprintf("%s/v1/gpu-nodes/%s/heartbeat", a.config.APIBaseURL, a.config.NodeID)
	req, err := http.NewRequestWithContext(a.ctx, "POST", url, bytes.NewReader(body))
	if err != nil {
		return err
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := a.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("heartbeat failed with status %d", resp.StatusCode)
	}

	log.Printf("Heartbeat sent: %s | VRAM: %d MB free", status, gpuInfo.VRAMFreeMB)
	return nil
}

// getGPUInfo retrieves current GPU information
func (a *Agent) getGPUInfo() (*GPUInfo, error) {
	// Use nvidia-smi to get GPU info
	cmd := exec.Command("nvidia-smi",
		"--query-gpu=name,memory.total,memory.free,utilization.gpu,temperature.gpu",
		"--format=csv,noheader,nounits")

	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	var name string
	var totalMB, freeMB, util, temp int
	fmt.Sscanf(string(output), "%s, %d, %d, %d, %d", &name, &totalMB, &freeMB, &util, &temp)

	return &GPUInfo{
		Count:        1, // TODO: Support multi-GPU
		Model:        name,
		VRAMTotalMB:  totalMB,
		VRAMFreeMB:   freeMB,
		Utilization:  util,
		Temperature:  temp,
	}, nil
}

// jobPollingLoop polls for new jobs
func (a *Agent) jobPollingLoop() {
	ticker := time.NewTicker(a.config.PollInterval)
	defer ticker.Stop()

	for {
		select {
		case <-a.ctx.Done():
			return
		case <-ticker.C:
			if a.currentJob == nil {
				job, err := a.pollForJob()
				if err != nil {
					log.Printf("Job poll failed: %v", err)
					continue
				}

				if job != nil {
					a.currentJob = job
					go a.executeJob(job)
				}
			}
		}
	}
}

// pollForJob polls the API for next job
func (a *Agent) pollForJob() (*Job, error) {
	url := fmt.Sprintf("%s/v1/gpu-nodes/%s/jobs/next", a.config.APIBaseURL, a.config.NodeID)
	req, err := http.NewRequestWithContext(a.ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	resp, err := a.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNoContent {
		return nil, nil // No jobs available
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("poll failed with status %d", resp.StatusCode)
	}

	var job Job
	if err := json.NewDecoder(resp.Body).Decode(&job); err != nil {
		return nil, err
	}

	log.Printf("Received job: %s (image: %s)", job.JobID, job.DockerImage)
	return &job, nil
}

// executeJob runs a job in a Docker container
func (a *Agent) executeJob(job *Job) {
	defer func() {
		a.currentJob = nil
	}()

	log.Printf("Starting job %s", job.JobID)

	// Update job status to RUNNING
	a.updateJobStatus(job.JobID, "RUNNING", 0, "")

	// Pull Docker image
	if err := a.pullDockerImage(job.DockerImage); err != nil {
		log.Printf("Failed to pull image: %v", err)
		a.updateJobStatus(job.JobID, "FAILED", 0, err.Error())
		return
	}

	// Run container
	if err := a.runDockerContainer(job); err != nil {
		log.Printf("Job failed: %v", err)
		a.updateJobStatus(job.JobID, "FAILED", 0, err.Error())
		return
	}

	log.Printf("Job %s completed successfully", job.JobID)
	a.updateJobStatus(job.JobID, "SUCCEEDED", 1.0, "")
}

// pullDockerImage pulls the Docker image
func (a *Agent) pullDockerImage(image string) error {
	log.Printf("Pulling image: %s", image)

	cmd := exec.CommandContext(a.ctx, "docker", "pull", image)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("docker pull failed: %w\n%s", err, output)
	}

	return nil
}

// runDockerContainer runs the job in a Docker container
func (a *Agent) runDockerContainer(job *Job) error {
	args := []string{
		"run",
		"--rm",
		"--gpus", "all",
		"--network", "none", // No network access for security
		"--memory", "24g",
		"--cpus", "8",
		"--read-only",        // Read-only filesystem
		"--tmpfs", "/tmp:rw,noexec,nosuid,size=10g",
		"--security-opt", "no-new-privileges",
	}

	// Add environment variables from secrets
	for key, value := range job.Secrets {
		args = append(args, "-e", fmt.Sprintf("%s=%s", key, value))
	}

	// Add config as JSON env var
	configJSON, _ := json.Marshal(job.Config)
	args = append(args, "-e", fmt.Sprintf("JOB_CONFIG=%s", configJSON))

	// Add job ID
	args = append(args, "-e", fmt.Sprintf("JOB_ID=%s", job.JobID))

	// Image name
	args = append(args, job.DockerImage)

	log.Printf("Running: docker %v", args)

	cmd := exec.CommandContext(a.ctx, "docker", args...)

	// Stream logs
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}

	if err := cmd.Start(); err != nil {
		return err
	}

	// Stream logs in background
	go a.streamLogs(job.JobID, stdout)
	go a.streamLogs(job.JobID, stderr)

	// Wait for completion
	if err := cmd.Wait(); err != nil {
		return fmt.Errorf("container execution failed: %w", err)
	}

	return nil
}

// streamLogs streams container logs to the API
func (a *Agent) streamLogs(jobID string, reader io.Reader) {
	buf := make([]byte, 1024)
	for {
		n, err := reader.Read(buf)
		if n > 0 {
			logLine := string(buf[:n])
			a.sendLogs(jobID, logLine)
			fmt.Print(logLine) // Also print locally
		}
		if err != nil {
			break
		}
	}
}

// sendLogs sends log chunk to the API
func (a *Agent) sendLogs(jobID, logs string) {
	url := fmt.Sprintf("%s/v1/jobs/%s/logs", a.config.APIBaseURL, jobID)
	payload := map[string]string{"logs": logs}
	body, _ := json.Marshal(payload)

	req, _ := http.NewRequestWithContext(a.ctx, "POST", url, bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	resp, err := a.httpClient.Do(req)
	if err != nil {
		log.Printf("Failed to send logs: %v", err)
		return
	}
	defer resp.Body.Close()
}

// updateJobStatus updates job status in the API
func (a *Agent) updateJobStatus(jobID, status string, progress float64, errorMsg string) {
	url := fmt.Sprintf("%s/v1/jobs/%s/status", a.config.APIBaseURL, jobID)

	payload := map[string]interface{}{
		"status":   status,
		"progress": progress,
	}
	if errorMsg != "" {
		payload["error"] = errorMsg
	}

	body, _ := json.Marshal(payload)

	req, _ := http.NewRequestWithContext(a.ctx, "POST", url, bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	resp, err := a.httpClient.Do(req)
	if err != nil {
		log.Printf("Failed to update status: %v", err)
		return
	}
	defer resp.Body.Close()

	log.Printf("Job %s status updated: %s", jobID, status)
}

func main() {
	// Parse command-line flags
	nodeID := flag.String("node-id", "", "GPU node ID (required)")
	nodeName := flag.String("name", "", "GPU node name")
	apiURL := flag.String("api", "https://api.train-my-ai.com", "API base URL")
	certPath := flag.String("cert", "./certs/client.crt", "mTLS certificate path")
	keyPath := flag.String("key", "./certs/client.key", "mTLS key path")
	pollInterval := flag.Duration("poll-interval", 10*time.Second, "Job polling interval")
	heartbeatInterval := flag.Duration("heartbeat-interval", 30*time.Second, "Heartbeat interval")

	flag.Parse()

	if *nodeID == "" {
		log.Fatal("--node-id is required")
	}

	config := Config{
		NodeID:            *nodeID,
		NodeName:          *nodeName,
		APIBaseURL:        *apiURL,
		MTLSCertPath:      *certPath,
		MTLSKeyPath:       *keyPath,
		PollInterval:      *pollInterval,
		HeartbeatInterval: *heartbeatInterval,
	}

	agent, err := NewAgent(config)
	if err != nil {
		log.Fatalf("Failed to create agent: %v", err)
	}

	if err := agent.Start(); err != nil {
		log.Fatalf("Agent error: %v", err)
	}
}
