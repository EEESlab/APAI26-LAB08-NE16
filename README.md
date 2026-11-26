# APAI-LAB08: NE16

## Material

Assignment: [here](_docs/assignment.docx)
Slides: [here](_docs/slides.pdf)


## How to deliver the assignment:

Use Virtuale, upload only the assignment file named as follows: LAB08_APAI_<name_surname>.pdf


**Assignment DEADLINE: Sunday 06/12/2026 (end of day, 23:59)**

___

## Quickstart

You are encouraged to work on your own laptop using the provided devcontainer (Option A). If that is not possible, you can use the virtual machine available on the lab machines (Option B).

### Option A: Your own laptop (devcontainer, recommended)

Requirements: [Docker](https://docs.docker.com/get-docker/), [VSCode](https://code.visualstudio.com/) and the VSCode [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension.

1. Open a terminal and clone this repository:
```
git clone https://github.com/EEESlab/APAI26-LAB08-NE16.git
cd APAI26-LAB08-NE16/
```
2. Open VSCode with `code .`
3. On VSCode, click on 'Reopen in container' (the first time, the container image is downloaded, which may take a while).
4. **Wait for the one-time NE16 setup to finish.** The first time the container is created, it enables the NE16 accelerator in the GVSoC simulator and rebuilds it (see `.devcontainer/setup-ne16.sh`). This takes several minutes and needs an internet connection. Follow the progress in the VSCode terminal showing the container setup, and wait for the message:
```
[setup-ne16] Done: GVSoC now includes a working NE16.
```
5. Open a new terminal in VSCode: the PULP SDK is configured automatically.
6. Check that everything works by running the default layer (see [How to run the code](#how-to-run-the-code)): the output must end with `> Success! No errors found.` and the layer statistics.
7. Now you're ready to start!

> If a run hangs right after printing `Layer info`, the NE16 setup did not complete. Run `bash .devcontainer/setup-ne16.sh` from the repository folder inside the container and check its output for errors.

On Windows, install [WSL 2](https://learn.microsoft.com/en-us/windows/wsl/install) first, and choose the Windows version of Docker Desktop (even if you work with WSL). If VSCode reports that Docker cannot be found, enable the WSL integration in Docker Desktop (Settings -> Resources -> WSL integration), then Apply & Restart.

### Option B: Lab machines (virtual machine)

The Ubuntu-based virtual machine already contains the PULP SDK and VSCode (used only to edit the code and open terminals), so no Docker container is needed.

1. From a browser **outside** the virtual machine, download the lab zip file from Virtuale (the only website reachable from the lab machines) and extract it (right-click -> Extract).
2. Go to `C:/VM_APAI` and double-click `PULP-box.ova`. When VirtualBox opens, click on "Finish"/"Fine".
3. Once the virtual machine is imported, start it with "Start"/"Avvia".
4. Log in with username `pulp-box` and password `pulp`.
5. From the VirtualBox top bar, open Machine -> File Manager (left panel: files of the PC, right panel: files of the VM). Enter the login credentials at the bottom of the right panel.
6. Drag and drop the extracted lab folder into a subdirectory of the VM home directory (you need write rights there).
7. Inside the VM, open a terminal and go to the lab folder with `cd`.
8. **[DO NOT FORGET]** Every time you open a new terminal run:
```
source setup_pulp_sdk.sh
```
9. Now you're ready to start!

## How to run the code

1. Generate the layer (all arguments are optional, see below):
```
python parameters_generate.py -ks 3 -cin 16 -cout 32 -osd 3
```
2. Compile and run it on the simulator:
```
make clean all run
```
A run takes a few seconds and ends with the output check and the layer statistics (operations, latency, MAC/cycle).

Repeat step 1 every time you change the layer: the generated files in `inc/data/` hold the dimensions, the data and the expected output of the layer.

If you work outside the container, install the Python dependencies with `pip install -r requirements.txt`.

## Lab overview

All exercises run a single convolution layer (stride 1, no padding, 8-bit input, weights and output) on the NE16 accelerator of the PULP cluster, simulated with GVSoC. No code has to be written: you change the layer with `parameters_generate.py`, run it, and analyze the measurements.

| Exercise | What you do |
|---|---|
| 1 - Theoretical performance (3x3) | Compute the peak MAC/cycle of an NE16 block, core and of the whole NE16 (no simulation) |
| 2 - 3x3 vs. 1x1 modes | Same computation for the 1x1 mode, and compare the two modes (no simulation) |
| 3 - Simulation measurements | Run the default layer with `-ks 1` and `-ks 3`, compare the measured MAC/cycle to the peaks |
| 4 - Varying layer size | Sweep the input channels (`-cin`) and the output spatial size (`-osd`) and explain the performance |
| 5 - Execution states | Count the NE16 execution states with the trace and `count_states.sh` |

Relevant files:
- [parameters_generate.py](parameters_generate.py): generates the layer data and the expected output in `inc/data/` (it uses [Ne16.py](Ne16.py) to pack the weights in the NE16 format).
- [src/layer.c](src/layer.c): configures the NE16 job (layer dimensions, mode, normalization and quantization), runs it, and measures its latency.
- [inc/nnx/](inc/nnx/) and [src/pulp_nnx_hal.c](src/pulp_nnx_hal.c): the NE16 driver that writes the job into the accelerator registers.
- [count_states.sh](count_states.sh): counts the NE16 execution states in a trace.

## - `parameters_generate.py` script

To see which arguments are available in the script, just run the below command:

```
python parameters_generate.py --help
```

Arguments
``` 
  --kernel-shape {1,3}, -ks {1,3}
                        Shape of the kernel. Choices: 1 or 3. Default: 3
  --channels-in CIN, -cin CIN
                        Number of input channels. Default: 16
  --channels-out COUT, -cout COUT
                        Number of output channels. Default: 32
  --output-spatial-dimensions SPATIAL_DIMENSIONS, -osd SPATIAL_DIMENSIONS
                        Output spatial dimension. Default 3
```

## Producing simulation logs

To produce simulation logs run the command:

```
make clean all run runner_args="--trace=ne16"
```

If you want to save it to a file, e.g. `ne16.log`, run the command:

```
make clean all run runner_args="--trace=ne16" > ne16.log
```


## Using the bash script for state counting

In the proceeding tasks, you will have to measure the number of states executed for different layers. To ease the counting, we created a script `count_states.sh`.
Quick usage guide:

If you want to use it on a file, call the script like this:

```
./count_states.sh ne16.log
```

Or you can pipe the output of the simulation directly to the script:

```
make all run runner_args="--trace=ne16" | ./count_states.sh
```
