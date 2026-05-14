# HoverGuard 🚁
### Autonomous Wind-Rejection Altitude Control for UAVs
> CONTROL CRAFT Hackathon · BNM Institute of Technology  
> Department of Electronics and Communication Engineering  
> Problem Statement 1: Drone Altitude Stabilization

---

## The Problem
Urban delivery drones and inspection UAVs face sudden wind gusts 
that destabilize altitude. Without proper control, a 0.5N wind gust 
causes dangerous oscillations that take seconds to recover from — 
or never recover at all.

**HoverGuard** is a PID-based altitude stabilization system that 
rejects wind disturbances and recovers to target altitude in under 
3 seconds.

---

## System Model
G(s) = 1 / (s² + 2s + 5)
| Parameter | Value |
|---|---|
| Natural frequency ωn | 2.236 rad/s |
| Damping ratio ζ | 0.447 (underdamped) |
| Open-loop poles | -1 ± 2i |
| Disturbance | 0.5N wind at t = 5s |

---

## Our Approach
We used **analytical pole placement** to design the PID controller 
rather than trial-and-error tuning:

1. Set target damping ratio ζ = 0.7 (ensures overshoot < 10%)
2. Set target settling time < 3s → minimum σ = 4/3 = 1.33
3. Derived desired closed-loop pole locations
4. Used MATLAB `pidtune` validated against manual calculations
5. Verified performance using `stepinfo` metrics

---

## Controller Performance

| Metric | Requirement | Achieved |
|---|---|---|
| Overshoot | < 10% | 3.35% ✓ |
| Settling time | < 3s | 2.48s ✓ |
| Steady-state error | ≈ 0 | < 0.001 ✓ |
| Disturbance rejection | Stable | ✓ |

**Final PID Gains:**
- Kp = 10.2543
- Ki = 13.1422  
- Kd = 1.9336

---

## Results

### 1. Open-Loop Step Response (No Controller)
![Open loop](results/01_open_loop_step_response.png)

### 2. Bode Plot Comparison
![Bode](results/02_bode_plot.png)

### 3. Closed-Loop PID Response
![Closed loop](results/03_closed_loop_pid_response.png)

### 4. Controller Evolution — P vs PD vs PID
![Comparison](results/04_controller_comparison_P_PD_PID.png)

### 5. Disturbance Response (Wind at t=5s)
![Disturbance](results/05_simulink_disturbance_response.png)

### 6. Robustness Analysis
![Robustness](results/06_robustness_sweep.png)

### 7. Root Locus
![Root locus](results/07_root_locus.png)

---

## Demo Video
[▶ Watch HoverGuard Demo](your-youtube-link-here)

---

## How to Run

### Requirements
- MATLAB R2023b or later
- Control System Toolbox
- Simulink

### Steps

1. Clone this repository
2. Open MATLAB and navigate to the project folder
3. Run scripts in this order:
   - open_loop_analysis.m
   - pid_design.m
   - controller_comparison.m
   - disturbance_analysis.m
   - root_locus_analysis.m
4. Open simulink/drone_altitude_model.slx for full simulation
5. HoverGuard.m — Live interactive dashboard with wind gust simulator
   
---

## Project Structure

| Folder | Contents |
|---|---|
| src/ | All MATLAB scripts |
| simulink/ | Simulink model (.slx) |
| results/ | Output plots and figures |
| README.md | Project documentation |

---

## Team
- Tanish Pranav — BNM Institute of Technology
