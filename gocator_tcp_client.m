%% Gocator 3210 Sensor TCP/IP Client
% This script establishes TCP/IP connections to two Gocator 3210 sensors
% and retrieves X-Y coordinate pairs using ASCII protocol.
%
% The script works with both physical sensors and the Gocator emulator.
% No Instrument Control Toolbox required - uses base MATLAB TCP functionality.

function gocator_tcp_client()
    % Define configuration parameters
    config = struct(...
        'sensors', [...
            struct('name', 'Sensor 1', 'ip', '192.168.1.10', 'enabled', true), ...
            struct('name', 'Sensor 2', 'ip', '192.168.1.11', 'enabled', true) ...
        ], ...
        'ports', struct('control', 3190, 'data', 3192, 'health', 3194), ...
        'timeout', 5, ... % Socket timeout in seconds
        'delimiter', ',', ... % Data delimiter in ASCII protocol
        'term_char', '\r\n' ... % Command termination character
    );
    
    % Initialize sensor connections
    sensors = initializeSensors(config);
    
    try
        % Main operation
        running = true;
        while running
            % Display menu
            disp(' ');
            disp('=== Gocator 3210 Sensor Control ===');
            disp('1. Get X-Y data from Sensor 1');
            disp('2. Get X-Y data from Sensor 2');
            disp('3. Get X-Y data from both sensors');
            disp('4. Start sensors');
            disp('5. Stop sensors');
            disp('6. Send software trigger');
            disp('7. Change sensor IPs');
            disp('8. Exit');
            
            % Get user choice
            choice = input('Enter choice (1-8): ', 's');
            
            % Process user choice
            switch choice
                case '1'
                    if sensors(1).enabled
                        getAndDisplayXYData(sensors(1));
                    else
                        disp('Sensor 1 is not enabled.');
                    end
                    
                case '2'
                    if sensors(2).enabled
                        getAndDisplayXYData(sensors(2));
                    else
                        disp('Sensor 2 is not enabled.');
                    end
                    
                case '3'
                    getXYDataFromAllSensors(sensors);
                    
                case '4'
                    startAllSensors(sensors);
                    
                case '5'
                    stopAllSensors(sensors);
                    
                case '6'
                    triggerAllSensors(sensors);
                    
                case '7'
                    sensors = configureSensorIPs(sensors, config);
                    
                case '8'
                    running = false;
                    disp('Exiting...');
                    
                otherwise
                    disp('Invalid choice. Please try again.');
            end
        end
    catch ex
        disp(['Error in main operation: ' ex.message]);
    end
    
    % Clean up resources
    cleanupSensors(sensors);
end

%% Initialize sensor connections
function sensors = initializeSensors(config)
    disp('Initializing sensor connections...');
    
    % Initialize sensor array
    sensors = struct('name', {}, 'ip', {}, 'enabled', {}, ...
                     'control', {}, 'data', {}, 'health', {});
    
    % Configure each sensor
    for i = 1:length(config.sensors)
        sensor = config.sensors(i);
        if sensor.enabled
            try
                % Create new sensor structure
                newSensor = struct(...
                    'name', sensor.name, ...
                    'ip', sensor.ip, ...
                    'enabled', sensor.enabled, ...
                    'control', [], ...
                    'data', [], ...
                    'health', []);
                
                % Create control socket
                newSensor.control = tcpip(sensor.ip, config.ports.control);
                set(newSensor.control, 'Timeout', config.timeout);
                
                % Create data socket
                newSensor.data = tcpip(sensor.ip, config.ports.data);
                set(newSensor.data, 'Timeout', config.timeout);
                
                % Create health socket
                newSensor.health = tcpip(sensor.ip, config.ports.health);
                set(newSensor.health, 'Timeout', config.timeout);
                
                % Open all connections
                fopen(newSensor.control);
                fopen(newSensor.data);
                fopen(newSensor.health);
                
                % Add to sensors array
                sensors(i) = newSensor;
                
                disp(['Successfully connected to ' sensor.name ' at ' sensor.ip]);
            catch ex
                warning(['Failed to connect to ' sensor.name ' at ' sensor.ip ': ' ex.message]);
                
                % Add disabled sensor to array
                sensors(i) = struct(...
                    'name', sensor.name, ...
                    'ip', sensor.ip, ...
                    'enabled', false, ...
                    'control', [], ...
                    'data', [], ...
                    'health', []);
            end
        else
            % Add disabled sensor to array
            sensors(i) = struct(...
                'name', sensor.name, ...
                'ip', sensor.ip, ...
                'enabled', false, ...
                'control', [], ...
                'data', [], ...
                'health', []);
        end
    end
end

%% Send command to sensor and get response
function [response, success] = sendCommand(socket, command, termChar)
    response = '';
    success = false;
    
    try
        % Add termination character if not present
        if ~endsWith(command, termChar)
            command = [command termChar];
        end
        
        % Send command
        fprintf(socket, command);
        
        % Get response
        response = fgetl(socket);
        success = true;
    catch ex
        warning(['Error sending command: ' ex.message]);
    end
end

%% Get X-Y coordinate data from sensor
function [xyData, success] = getXYData(sensor)
    % Initialize return values
    xyData = struct('x', [], 'y', []);
    success = false;
    
    try
        if ~sensor.enabled
            return;
        end
        
        % Send result request command to data channel
        [response, cmdSuccess] = sendCommand(sensor.data, 'Result', '\r\n');
        
        if cmdSuccess && ~isempty(response)
            % Parse the response to extract X-Y data
            [xyData, success] = parseXYDataFromResponse(response);
        else
            warning([sensor.name ': No valid response received']);
        end
    catch ex
        warning([sensor.name ': Error getting X-Y data: ' ex.message]);
    end
end

%% Parse X-Y data from sensor response
function [xyData, success] = parseXYDataFromResponse(response)
    % Initialize return values
    xyData = struct('x', [], 'y', []);
    success = false;
    
    try
        % Split response by delimiter (comma)
        parts = strsplit(response, ',');
        
        % Verify response format (should begin with 'DATA')
        if length(parts) >= 5 && strcmp(parts{1}, 'DATA')
            % Extract frame information
            frameCount = str2double(parts{2});
            timeStamp = str2double(parts{3});
            
            % Calculate number of X-Y pairs
            % Assuming format: DATA,frameCount,timeStamp,X1,Y1,X2,Y2,...
            numPairs = floor((length(parts) - 3) / 2);
            
            if numPairs > 0
                % Initialize arrays for X and Y coordinates
                xyData.x = zeros(1, numPairs);
                xyData.y = zeros(1, numPairs);
                
                % Extract X-Y pairs
                for i = 1:numPairs
                    xIndex = 3 + (i-1)*2 + 1;
                    yIndex = xIndex + 1;
                    
                    if xIndex <= length(parts) && yIndex <= length(parts)
                        xyData.x(i) = str2double(parts{xIndex});
                        xyData.y(i) = str2double(parts{yIndex});
                    end
                end
                
                success = true;
            end
        else
            % Handle custom or unexpected response format
            % You might need to adjust this based on your specific sensor configuration
            warning(['Unexpected response format: ' response]);
        end
    catch ex
        warning(['Error parsing X-Y data: ' ex.message]);
    end
end

%% Get and display X-Y data from one sensor
function getAndDisplayXYData(sensor)
    disp(['Getting X-Y data from ' sensor.name ' at ' sensor.ip '...']);
    
    % Get X-Y data
    [xyData, success] = getXYData(sensor);
    
    if success
        % Display X-Y data
        displayXYData(sensor.name, xyData);
    else
        disp(['Failed to get valid X-Y data from ' sensor.name]);
    end
end

%% Display X-Y data
function displayXYData(sensorName, xyData)
    disp(['X-Y Coordinate Data from ' sensorName ':']);
    
    if isempty(xyData.x) || isempty(xyData.y)
        disp('  No X-Y coordinate data available');
        return;
    end
    
    % Display all coordinate pairs
    for i = 1:length(xyData.x)
        disp(sprintf('  Point %d: X = %.6f, Y = %.6f', ...
            i, xyData.x(i), xyData.y(i)));
    end
end

%% Get X-Y data from all sensors
function getXYDataFromAllSensors(sensors)
    % Get data from all enabled sensors
    for i = 1:length(sensors)
        if sensors(i).enabled
            getAndDisplayXYData(sensors(i));
        end
    end
end

%% Start all sensors
function startAllSensors(sensors)
    disp('Starting all sensors...');
    
    % Start each enabled sensor
    for i = 1:length(sensors)
        if sensors(i).enabled
            [response, success] = sendCommand(sensors(i).control, 'Start', '\r\n');
            
            if success
                disp([sensors(i).name ': ' response]);
            else
                disp([sensors(i).name ': Failed to start']);
            end
        end
    end
end

%% Stop all sensors
function stopAllSensors(sensors)
    disp('Stopping all sensors...');
    
    % Stop each enabled sensor
    for i = 1:length(sensors)
        if sensors(i).enabled
            [response, success] = sendCommand(sensors(i).control, 'Stop', '\r\n');
            
            if success
                disp([sensors(i).name ': ' response]);
            else
                disp([sensors(i).name ': Failed to stop']);
            end
        end
    end
end

%% Trigger all sensors
function triggerAllSensors(sensors)
    disp('Sending software trigger to all sensors...');
    
    % Trigger each enabled sensor
    for i = 1:length(sensors)
        if sensors(i).enabled
            [response, success] = sendCommand(sensors(i).control, 'Trigger', '\r\n');
            
            if success
                disp([sensors(i).name ': ' response]);
            else
                disp([sensors(i).name ': Failed to trigger']);
            end
        end
    end
end

%% Configure sensor IPs
function sensors = configureSensorIPs(sensors, config)
    % Prompt for new IPs
    for i = 1:length(sensors)
        newIP = input(['Enter new IP for ' sensors(i).name ' (current: ' sensors(i).ip ', press Enter to keep): '], 's');
        
        % Update IP if provided
        if ~isempty(newIP)
            % Close current connections if enabled
            if sensors(i).enabled
                cleanupSensor(sensors(i));
            end
            
            % Update IP
            sensors(i).ip = newIP;
            sensors(i).enabled = true;
            
            % Try to connect with new IP
            try
                % Create control socket
                sensors(i).control = tcpip(newIP, config.ports.control);
                set(sensors(i).control, 'Timeout', config.timeout);
                
                % Create data socket
                sensors(i).data = tcpip(newIP, config.ports.data);
                set(sensors(i).data, 'Timeout', config.timeout);
                
                % Create health socket
                sensors(i).health = tcpip(newIP, config.ports.health);
                set(sensors(i).health, 'Timeout', config.timeout);
                
                % Open all connections
                fopen(sensors(i).control);
                fopen(sensors(i).data);
                fopen(sensors(i).health);
                
                disp(['Successfully connected to ' sensors(i).name ' at ' newIP]);
            catch ex
                warning(['Failed to connect to ' sensors(i).name ' at ' newIP ': ' ex.message]);
                sensors(i).enabled = false;
            end
        end
    end
end

%% Clean up single sensor
function cleanupSensor(sensor)
    try
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
    catch ex
        warning(['Error cleaning up ' sensor.name ': ' ex.message]);
    end
end

%% Clean up all sensors
function cleanupSensors(sensors)
    disp('Cleaning up sensor connections...');
    
    % Clean up each sensor
    for i = 1:length(sensors)
        if sensors(i).enabled
            cleanupSensor(sensors(i));
            disp([sensors(i).name ': Connections closed']);
        end
    end
end
