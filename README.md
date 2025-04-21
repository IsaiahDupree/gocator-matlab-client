# Gocator 3210 Sensor Communication in MATLAB

This repository contains MATLAB scripts for communicating with Gocator 3210 3D snapshot sensors via TCP/IP using the ASCII protocol.

## Overview

The scripts establish connections to Gocator 3210 sensors to retrieve X-Y coordinate data. All implementations use the base MATLAB TCP/IP functionality without requiring the Instrument Control Toolbox.

## Files

- `gocator_tcp_client.m` - Main client for connecting to two physical sensors with full functionality
- `gocator_sensor_client.m` - Basic client for connecting to two physical sensors
- `gocator_emulator_client.m` - Specialized client for working with the Gocator emulator tool
- `sample_xy_data.txt` - Sample data for testing with the Gocator emulator

## Features

- Connection to sensors via three TCP/IP channels (control, data, and health)
- Polling for X-Y coordinate data on demand
- Commands to start, stop, and trigger the sensors
- Configurable IP addresses for sensors
- Error handling and connection cleanup
- Support for the Gocator emulator for testing without physical hardware

## Usage

### For Physical Sensors
```matlab
% Run the main client
gocator_tcp_client
```

### For Emulator Testing
```matlab
% Run the emulator client
gocator_emulator_client
```

## Sensor Documentation

- [Gocator 3210 Product Page](https://lmi3d.com/series/gocator-3210/)
- [Gocator Documentation](https://d3ejaiy6gq5z4s.cloudfront.net/manuals/gocator/gocator-6.4/G3/Default.htm#Welcome.htm?TocPath=_____1)
- [Gocator Emulator](https://d3ejaiy6gq5z4s.cloudfront.net/manuals/gocator/gocator-6.4/G3/Default.htm#Emulator/Emulator.htm?TocPath=Gocator%2520Emulator%257C_____0)
