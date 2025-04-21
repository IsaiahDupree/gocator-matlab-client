%% Gocator 3210 Sensor Communication Script
% This script connects to two Gocator 3210 sensors via TCP/IP using ASCII protocol
% to retrieve X-Y coordinate data on demand.
%
% The script uses basic MATLAB TCP/IP functionality (not Instrument Control Toolbox)
% to communicate with the sensors or the emulator.

function gocator_sensor_client()
    % Configuration parameters
    config = struct(...
        'sensor1_ip', '192.168.1.10', ... % Default IP for first sensor, change as needed
        'sensor2_ip', '192.168.1.11', ... % Default IP for second sensor, change as needed
        'control_port', 3190, ... % Default control port
        'data_port', 3192, ... % Default data port
        'health_port', 3194, ... % Default health port
        'timeout_seconds', 5 ... % Socket timeout in seconds
    );
    
    % Initialize connections
    sensor1 = struct('control', [], 'data', [], 'health', []);
    sensor2 = struct('control', [], 'data', [], 'health', []);
    
    try
        % Connect to both sensors
        disp('Connecting to Gocator sensors...');
        sensor1 = connectToSensor(config.sensor1_ip, config);
        sensor2 = connectToSensor(config.sensor2_ip, config);
        disp('Successfully connected to both sensors.');
        
        % Main interaction loop
        running = true;
        while running
            disp(' ');
            disp('== Gocator Sensor Control ==');
            disp('1. Get measurements from Sensor 1');
            disp('2. Get measurements from Sensor 2');
            disp('3. Get measurements from both sensors');
            disp('4. Start sensors');
            disp('5. Stop sensors');
            disp('6. Exit');
            choice = input('Enter choice (1-6): ', 's');
            
            switch choice
                case '1'
                    getAndDisplayMeasurements(sensor1, 'Sensor 1');
                case '2'
                    getAndDisplayMeasurements(sensor2, 'Sensor 2');
                case '3'
                    disp('Getting measurements from both sensors...');
                    [sensor1Data, success1] = getMeasurements(sensor1);
                    [sensor2Data, success2] = getMeasurements(sensor2);
                    
                    if success1 && success2
                        displayMeasurements(sensor1Data, 'Sensor 1');
                        displayMeasurements(sensor2Data, 'Sensor 2');
                    else
                        disp('Failed to get measurements from one or both sensors.');
                    end
                case '4'
                    startSensors(sensor1, sensor2);
                case '5'
                    stopSensors(sensor1, sensor2);
                case '6'
                    running = false;
                    disp('Exiting program...');
                otherwise
                    disp('Invalid choice, please try again.');
            end
        end
    catch ex
        disp(['Error: ' ex.message]);
    end
    
    % Clean up connections
    cleanupConnections(sensor1, sensor2);
end

%% Function to connect to a sensor
function sensor = connectToSensor(ip, config)
    sensor = struct('control', [], 'data', [], 'health', []);
    
    try
        % Create TCP/IP socket for control channel
        sensor.control = tcpip(ip, config.control_port);
        set(sensor.control, 'Timeout', config.timeout_seconds);
        
        % Create TCP/IP socket for data channel
        sensor.data = tcpip(ip, config.data_port);
        set(sensor.data, 'Timeout', config.timeout_seconds);
        
        % Create TCP/IP socket for health channel
        sensor.health = tcpip(ip, config.health_port);
        set(sensor.health, 'Timeout', config.timeout_seconds);
        
        % Open connections
        fopen(sensor.control);
        fopen(sensor.data);
        fopen(sensor.health);
        
        disp(['Successfully connected to sensor at ' ip]);
    catch ex
        cleanupConnection(sensor);
        error(['Failed to connect to sensor at ' ip ': ' ex.message]);
    end
end

%% Function to get measurements from a sensor
function [measurementData, success] = getMeasurements(sensor)
    measurementData = struct('x', [], 'y', []);
    success = false;
    
    try
        % Send polling command to request results
        fprintf(sensor.data, 'Result\r\n');
        
        % Read response
        response = fgetl(sensor.data);
        
        if ~isempty(response)
            % Parse the measurement data
            measurementData = parseMeasurementData(response);
            success = true;
        else
            disp('Warning: Received empty response from sensor');
        end
    catch ex
        disp(['Error getting measurements: ' ex.message]);
    end
end

%% Function to parse measurement data
function data = parseMeasurementData(response)
    % Initialize data structure
    data = struct('x', [], 'y', []);
    
    try
        % Sample response format: DATA,<frame count>,<timestamp>,<x1>,<y1>,<x2>,<y2>,...
        % Note: Actual format depends on sensor configuration
        parts = strsplit(response, ',');
        
        if length(parts) >= 4 && strcmp(parts{1}, 'DATA')
            % Extract the X and Y values
            % Assuming format is DATA,<count>,<timestamp>,<X>,<Y>
            % Adjust parsing logic based on actual response format
            data.x = str2double(parts{4});
            data.y = str2double(parts{5});
            
            % If there are multiple coordinate pairs
            % This part needs to be adjusted based on actual format
            if length(parts) > 5
                % Process additional coordinate pairs if present
                numPoints = floor((length(parts) - 3) / 2);
                data.x = zeros(1, numPoints);
                data.y = zeros(1, numPoints);
                
                for i = 1:numPoints
                    xIndex = 3 + (i-1)*2 + 1;
                    yIndex = xIndex + 1;
                    
                    if xIndex <= length(parts) && yIndex <= length(parts)
                        data.x(i) = str2double(parts{xIndex});
                        data.y(i) = str2double(parts{yIndex});
                    end
                end
            end
        else
            disp(['Warning: Unexpected response format: ' response]);
        end
    catch ex
        disp(['Error parsing measurement data: ' ex.message]);
    end
end

%% Function to display measurements
function displayMeasurements(data, sensorName)
    disp(['Measurements from ' sensorName ':']);
    
    if isempty(data.x) || isempty(data.y)
        disp('  No valid measurement data received.');
        return;
    end
    
    for i = 1:length(data.x)
        disp(['  Point ' num2str(i) ': X = ' num2str(data.x(i)) ', Y = ' num2str(data.y(i))]);
    end
end

%% Function to get and display measurements
function getAndDisplayMeasurements(sensor, sensorName)
    disp(['Getting measurements from ' sensorName '...']);
    [data, success] = getMeasurements(sensor);
    
    if success
        displayMeasurements(data, sensorName);
    else
        disp(['Failed to get measurements from ' sensorName '.']);
    end
end

%% Function to start sensors
function startSensors(sensor1, sensor2)
    try
        % Send start command to both sensors
        fprintf(sensor1.control, 'Start\r\n');
        fprintf(sensor2.control, 'Start\r\n');
        
        % Read responses
        response1 = fgetl(sensor1.control);
        response2 = fgetl(sensor2.control);
        
        % Check responses
        if contains(response1, 'OK') && contains(response2, 'OK')
            disp('Both sensors started successfully.');
        else
            disp('Warning: One or both sensors may not have started properly.');
            disp(['Sensor 1 response: ' response1]);
            disp(['Sensor 2 response: ' response2]);
        end
    catch ex
        disp(['Error starting sensors: ' ex.message]);
    end
end

%% Function to stop sensors
function stopSensors(sensor1, sensor2)
    try
        % Send stop command to both sensors
        fprintf(sensor1.control, 'Stop\r\n');
        fprintf(sensor2.control, 'Stop\r\n');
        
        % Read responses
        response1 = fgetl(sensor1.control);
        response2 = fgetl(sensor2.control);
        
        % Check responses
        if contains(response1, 'OK') && contains(response2, 'OK')
            disp('Both sensors stopped successfully.');
        else
            disp('Warning: One or both sensors may not have stopped properly.');
            disp(['Sensor 1 response: ' response1]);
            disp(['Sensor 2 response: ' response2]);
        end
    catch ex
        disp(['Error stopping sensors: ' ex.message]);
    end
end

%% Function to clean up a single connection
function cleanupConnection(sensor)
    % Close control channel
    if ~isempty(sensor.control) && isvalid(sensor.control)
        if strcmp(get(sensor.control, 'Status'), 'open')
            fclose(sensor.control);
        end
        delete(sensor.control);
    end
    
    % Close data channel
    if ~isempty(sensor.data) && isvalid(sensor.data)
        if strcmp(get(sensor.data, 'Status'), 'open')
            fclose(sensor.data);
        end
        delete(sensor.data);
    end
    
    % Close health channel
    if ~isempty(sensor.health) && isvalid(sensor.health)
        if strcmp(get(sensor.health, 'Status'), 'open')
            fclose(sensor.health);
        end
        delete(sensor.health);
    end
end

%% Function to clean up all connections
function cleanupConnections(sensor1, sensor2)
    disp('Cleaning up connections...');
    cleanupConnection(sensor1);
    cleanupConnection(sensor2);
    disp('All connections closed.');
end
