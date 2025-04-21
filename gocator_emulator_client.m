%% Gocator Emulator Client
% This script connects to the Gocator emulator via TCP/IP using ASCII protocol
% to retrieve X-Y coordinate data for testing purposes.
%
% Instructions:
% 1. Start the Gocator emulator tool (mentioned in documentation)
% 2. Configure the emulator with the IP addresses defined in this script
% 3. Run this script to test communication and data retrieval
%
% No Instrument Control Toolbox required - uses base MATLAB TCP functionality.

function gocator_emulator_client()
    % Configuration for emulator connections
    config = struct(...
        'emulator_ip', '127.0.0.1', ... % Default emulator IP (localhost)
        'sensors', [...
            struct('name', 'Emulated Sensor 1', 'port_offset', 0), ...
            struct('name', 'Emulated Sensor 2', 'port_offset', 10) ...
        ], ...
        'base_ports', struct('control', 3190, 'data', 3192, 'health', 3194), ...
        'timeout', 5, ... % Socket timeout in seconds
        'term_char', '\r\n' ... % Command termination character
    );
    
    % Initialize emulated sensors
    sensors = initializeEmulatedSensors(config);
    
    try
        % Main operation
        running = true;
        while running
            % Display menu
            disp(' ');
            disp('=== Gocator Emulator Test Client ===');
            disp('1. Get X-Y data from Emulated Sensor 1');
            disp('2. Get X-Y data from Emulated Sensor 2');
            disp('3. Get X-Y data from both emulated sensors');
            disp('4. Start emulated sensors');
            disp('5. Stop emulated sensors');
            disp('6. Send software trigger to emulated sensors');
            disp('7. Load sample data into emulator');
            disp('8. Exit');
            
            % Get user choice
            choice = input('Enter choice (1-8): ', 's');
            
            % Process user choice
            switch choice
                case '1'
                    if sensors(1).enabled
                        getAndDisplayXYData(sensors(1));
                    else
                        disp('Emulated Sensor 1 is not connected.');
                    end
                    
                case '2'
                    if sensors(2).enabled
                        getAndDisplayXYData(sensors(2));
                    else
                        disp('Emulated Sensor 2 is not connected.');
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
                    loadSampleData();
                    
                case '8'
                    running = false;
                    disp('Exiting emulator test client...');
                    
                otherwise
                    disp('Invalid choice. Please try again.');
            end
        end
    catch ex
        disp(['Error in emulator test client: ' ex.message]);
    end
    
    % Clean up resources
    cleanupSensors(sensors);
end

%% Initialize emulated sensor connections
function sensors = initializeEmulatedSensors(config)
    disp('Initializing emulated sensor connections...');
    
    % Initialize sensor array
    sensors = struct('name', {}, 'enabled', {}, ...
                     'control', {}, 'data', {}, 'health', {});
    
    % Configure each emulated sensor
    for i = 1:length(config.sensors)
        sensor = config.sensors(i);
        
        try
            % Calculate ports for this emulated sensor
            controlPort = config.base_ports.control + sensor.port_offset;
            dataPort = config.base_ports.data + sensor.port_offset;
            healthPort = config.base_ports.health + sensor.port_offset;
            
            % Create new sensor structure
            newSensor = struct(...
                'name', sensor.name, ...
                'enabled', false, ...
                'control', [], ...
                'data', [], ...
                'health', []);
            
            % Create control socket
            newSensor.control = tcpip(config.emulator_ip, controlPort);
            set(newSensor.control, 'Timeout', config.timeout);
            
            % Create data socket
            newSensor.data = tcpip(config.emulator_ip, dataPort);
            set(newSensor.data, 'Timeout', config.timeout);
            
            % Create health socket
            newSensor.health = tcpip(config.emulator_ip, healthPort);
            set(newSensor.health, 'Timeout', config.timeout);
            
            % Open all connections
            fopen(newSensor.control);
            fopen(newSensor.data);
            fopen(newSensor.health);
            
            % Mark as enabled
            newSensor.enabled = true;
            
            % Add to sensors array
            sensors(i) = newSensor;
            
            disp(['Successfully connected to ' sensor.name ' at ' config.emulator_ip ':' num2str(controlPort)]);
        catch ex
            warning(['Failed to connect to ' sensor.name ': ' ex.message]);
            
            % Add disabled sensor to array
            sensors(i) = struct(...
                'name', sensor.name, ...
                'enabled', false, ...
                'control', [], ...
                'data', [], ...
                'health', []);
        end
    end
end

%% Send command to emulated sensor and get response
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
        warning(['Error sending command to emulator: ' ex.message]);
    end
end

%% Get X-Y coordinate data from emulated sensor
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
            warning([sensor.name ': No valid response received from emulator']);
        end
    catch ex
        warning([sensor.name ': Error getting X-Y data from emulator: ' ex.message]);
    end
end

%% Parse X-Y data from emulated sensor response
function [xyData, success] = parseXYDataFromResponse(response)
    % Initialize return values
    xyData = struct('x', [], 'y', []);
    success = false;
    
    try
        % For emulator testing, we'll handle both standard and custom formats
        
        % Check if response is in the standard format
        if startsWith(response, 'DATA')
            % Split response by delimiter (comma)
            parts = strsplit(response, ',');
            
            % Verify response format (should begin with 'DATA')
            if length(parts) >= 5
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
            end
        else
            % Custom format handling for the emulator
            % This could be a simple format for testing
            
            % Try to parse as direct X,Y pairs
            parts = strsplit(response, ',');
            if mod(length(parts), 2) == 0
                % Even number of parts suggests X,Y pairs
                numPairs = length(parts) / 2;
                
                % Initialize arrays
                xyData.x = zeros(1, numPairs);
                xyData.y = zeros(1, numPairs);
                
                % Extract pairs
                for i = 1:numPairs
                    xIndex = (i-1)*2 + 1;
                    yIndex = xIndex + 1;
                    
                    xyData.x(i) = str2double(parts{xIndex});
                    xyData.y(i) = str2double(parts{yIndex});
                end
                
                success = true;
            else
                disp(['Unrecognized emulator response format: ' response]);
            end
        end
    catch ex
        warning(['Error parsing emulator X-Y data: ' ex.message]);
    end
end

%% Get and display X-Y data from one emulated sensor
function getAndDisplayXYData(sensor)
    disp(['Getting X-Y data from ' sensor.name '...']);
    
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

%% Get X-Y data from all emulated sensors
function getXYDataFromAllSensors(sensors)
    % Get data from all enabled sensors
    for i = 1:length(sensors)
        if sensors(i).enabled
            getAndDisplayXYData(sensors(i));
        end
    end
end

%% Start all emulated sensors
function startAllSensors(sensors)
    disp('Starting all emulated sensors...');
    
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

%% Stop all emulated sensors
function stopAllSensors(sensors)
    disp('Stopping all emulated sensors...');
    
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

%% Trigger all emulated sensors
function triggerAllSensors(sensors)
    disp('Sending software trigger to all emulated sensors...');
    
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

%% Load sample data into emulator
function loadSampleData()
    try
        % Sample data generation for testing
        disp('Generating sample X-Y coordinate data for emulator testing...');
        
        % Check if sample data file exists, otherwise create it
        sampleFile = 'sample_xy_data.txt';
        
        if ~exist(sampleFile, 'file')
            % Generate sample data
            numPoints = 10;
            xCoords = 10 * rand(1, numPoints);
            yCoords = 10 * rand(1, numPoints);
            
            % Open file for writing
            fid = fopen(sampleFile, 'w');
            
            % Write data format info
            fprintf(fid, '# Sample X-Y coordinate data for Gocator emulator\n');
            fprintf(fid, '# Format: DATA,frameCount,timestamp,X1,Y1,X2,Y2,...\n');
            
            % Create data line
            dataLine = 'DATA,1,12345';
            for i = 1:numPoints
                dataLine = [dataLine sprintf(',%.6f,%.6f', xCoords(i), yCoords(i))];
            end
            
            % Write data line
            fprintf(fid, '%s\n', dataLine);
            
            % Close file
            fclose(fid);
            
            disp(['Sample data file created: ' sampleFile]);
        else
            disp(['Using existing sample data file: ' sampleFile]);
        end
        
        % Instructions for loading into emulator
        disp(' ');
        disp('Instructions for loading sample data into the Gocator emulator:');
        disp('1. Open the Gocator emulator application');
        disp('2. Navigate to the Data Configuration section');
        disp('3. Click "Import Data" or equivalent option');
        disp(['4. Select the file: ' sampleFile]);
        disp('5. Set the data format to ASCII');
        disp('6. Apply the settings');
        disp(' ');
        disp('Note: The exact steps may vary depending on your emulator version.');
    catch ex
        disp(['Error creating sample data: ' ex.message]);
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
    disp('Cleaning up emulator connections...');
    
    % Clean up each sensor
    for i = 1:length(sensors)
        if sensors(i).enabled
            cleanupSensor(sensors(i));
            disp([sensors(i).name ': Connections closed']);
        end
    end
end
