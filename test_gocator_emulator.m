%% Automated Test Script for Gocator Emulator
% This script automatically tests the Gocator emulator client functionality
% by running through a sequence of operations and validating the results

function test_gocator_emulator()
    % Run the main client in automated test mode
    try
        gocator_emulator_client(true);
    catch ME
        disp('Test failed with error:');
        disp(ME.message);
        if ~isempty(ME.cause)
            disp('Caused by:');
            disp(ME.cause{1}.message);
        end
    end
end

function validateSensors(sensors)
    if isempty(sensors)
        error('No sensors initialized');
    end
    
    % Check if at least one sensor is enabled
    hasEnabledSensor = false;
    for i = 1:length(sensors)
        if isfield(sensors(i), 'enabled') && sensors(i).enabled
            hasEnabledSensor = true;
            break;
        end
    end
    
    if ~hasEnabledSensor
        error('No sensors are properly initialized and enabled');
    end
    
    % Display status of each sensor
    for i = 1:length(sensors)
        if isfield(sensors(i), 'enabled') && sensors(i).enabled
            disp(['Sensor ' num2str(i) ' is properly initialized and enabled']);
        else
            disp(['Warning: Sensor ' num2str(i) ' is not enabled or not properly initialized']);
        end
    end
end

function displayResults(data1, data2)
    disp('Results from Sensor 1:');
    disp(['X values: ' mat2str(data1.x)]);
    disp(['Y values: ' mat2str(data1.y)]);
    disp('Results from Sensor 2:');
    disp(['X values: ' mat2str(data2.x)]);
    disp(['Y values: ' mat2str(data2.y)]);
end
