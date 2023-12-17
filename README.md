# Sunrise Simulation for DIRIGERA Hub + TRÅDFRI LED Bulbs

Missing the sunrise simulation feature from the old IKEA TRÅDFRI gateway? You're not alone! Since IKEA replaced it with the new DIRIGERA Hub, that feature has disappeared, even though it was really helpful for waking up gently, especially when the sun doesn't rise as early during winter. This script brings it back, hopefully helping you wake up naturally during those dark winter mornings without spending a lot of money on a fancy wakeup light. I'm using this script with the "DIRIGERA Hub for smart products, white smart" (105.034.06) and two "TRÅDFRI LED bulb E27 806 lumen" (704.391.58).

## Prerequisites

To ensure the script runs smoothly, the following dependencies are required:

1. **bash**: The shell environment to run the script.
2. **curl**: Used for sending requests to the DIRIGERA Hub.
3. **bc**: A command-line calculator, utilized for floating-point arithmetic in the script.
4. **awk**: A text processing tool, used for calculations and data manipulation in the script.

These dependencies are commonly pre-installed on most Unix-like systems. If not, they can usually be installed via the system's package manager.

## Configuration

First, you need to grab a few details:

1. **API token** for your DIRIGERA Hub.
2. **Hostname or IP** of the DIRIGERA Hub.
3. **Bulb IDs** that you want to control.

Replace `CHANGEME` in the script with these details. There are comments in the script to guide you through.

### Obtaining the API Token and Bulb IDs

The easiest way to obtain the API token for the DIRIGERA Hub is to use the `dirigera-client-dump.jar` Java application available in the [DirigeraClient](https://github.com/dvdgeisler/DirigeraClient/tree/main) repository. Instructions are in that repository's `README.md` file. When you successfully run it, it will save the API token to a file called `dirigera_access_token` and also dump the hub's configuration to standard output, which will include the bulb IDs. The API token is good for several years, so you only need to grab it once.

### Configuring the Simulation

Adjust the simulation to your liking! You can set:

* **Duration**: How long the sunrise takes.
* **Steps**: The smoothness of the color transition.
* **Colors**: The hues and brightness levels throughout the simulation.

Feel free to play around with these settings until you find something that works for you. You can also just leave them alone for something that I personally think works fairly well.

## Automation with Cron Job or Systemd Timer

You might want this script to run automatically at a set time each morning. Below are two ways to do so. These assume you want to wake up at 7:30 AM, so they trigger at 7:00 AM, because by default the simulation runs its course over 30 minutes. Edit the `simulation_duration` and possibly the `steps` settings in the script to adjust this as necessary.

### Using Cron:

1. Open your terminal.
2. Type `crontab -e` to edit your cron jobs.
3. Add a line like this: `0 7 * * * /path/to/sunrise.sh`. This example sets the script to run at 7:00 AM every day. Adjust the time to your preference.
4. Save and exit the editor.

### Using Systemd:

#### Create the `.service` File

This file tells systemd what to do. Create a file named `sunrise.service` (or a name of your choice) and include the following content:

```ini
[Unit]
Description=Sunrise Simulation Script

[Service]
ExecStart=/path/to/sunrise.sh
```

Replace `/path/to/sunrise.sh` with the actual path to your script. 

#### Create the `.timer` File

This file schedules when the service should run. Create a file named `sunrise.timer` and include the following content:

```ini
[Unit]
Description=Run Sunrise Simulation Daily at 7 AM

[Timer]
OnCalendar=*-*-* 07:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

This configuration will trigger the sunrise simulation every day at 7 AM. You can adjust the `OnCalendar` value to change the schedule. The format is `YYYY-MM-DD HH:MM:SS`, and you can use wildcards (`*`) as shown to repeat the schedule.

#### Enable the Timer

After creating these files, place them in `/etc/systemd/system/`. Then, use the following commands to start and enable the timer:

```bash
sudo systemctl start sunrise.timer
sudo systemctl enable sunrise.timer
```

This will activate the timer and ensure it persists across reboots.

## Known Issues & Workarounds

TRÅDFRI LED bulbs don't accept commands when they're soft-off. This means they can't start the wakeup simulation in a dim state if they were turned off (by software) before the script runs. As a workaround, the script sets the initial light state for the next sunrise simulation right before turning the bulbs off once the auto-off timeout has elapsed. So, if you have dedicated wake-up bulbs, they'll at least start in a dim state.

If you encounter any issues or have suggestions, feel free to contribute or reach out. Just keep in mind that I don't know a lot about how IKEA's DIRIGERA hub or their TRÅDFRI LED bulbs actually work internally. I spent an hour or so on Google to find and reverse engineer just the bits I needed for this script to work.


