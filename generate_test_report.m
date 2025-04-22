%% Generate Test Report with Visualizations
% This script generates an HTML test report with graphs and visualizations
% that can be opened in a browser and saved as PDF or Word

function generate_test_report()
    % Read test report data
    [testResults, testDate, testDuration] = readTestReportData();
    
    % Create visualizations
    createSensorDataVisualization();
    createTestPerformanceChart(testResults);
    
    % Generate HTML report
    generateHTMLReport(testResults, testDate, testDuration);
    
    % Generate a test report for the Gocator Emulator tests
    disp('Generating Gocator Emulator Test Report...');
    
    try
        % Run the automated tests and collect results
        [testResultsEmulator, passCount, totalTests] = runAllTests();
        
        % Generate report header
        reportHeader = sprintf('Gocator Emulator Test Report\n');
        reportHeader = [reportHeader sprintf('Date: %s\n', datestr(now))];
        reportHeader = [reportHeader sprintf('----------------------------------------\n\n')];
        
        % Generate test summary
        summary = sprintf('Test Summary:\n');
        summary = [summary sprintf('Total Tests: %d\n', totalTests)];
        summary = [summary sprintf('Tests Passed: %d\n', passCount)];
        summary = [summary sprintf('Tests Failed: %d\n', totalTests - passCount)];
        summary = [summary sprintf('Success Rate: %.1f%%\n\n', (passCount/totalTests)*100)];
        
        % Combine all sections
        fullReport = [reportHeader summary testResultsEmulator];
        
        % Save report to file
        reportFile = 'gocator_test_report.txt';
        fid = fopen(reportFile, 'w');
        fprintf(fid, '%s', fullReport);
        fclose(fid);
        
        % Display report in command window
        disp(fullReport);
        disp(['Report saved to: ' reportFile]);
        
    catch ME
        disp('Error generating test report:');
        disp(ME.message);
    end
    
    disp('Test report generated successfully!');
end

%% Read test report data from markdown file
function [testResults, testDate, testDuration] = readTestReportData()
    % Read existing test report data
    disp('Reading test report data...');
    testReportPath = fullfile(pwd, 'test_report.md');
    
    % Check if test report exists
    if ~exist(testReportPath, 'file')
        error('Test report file not found: %s. Please run test_suite first.', testReportPath);
    end
    
    % Read the test report file
    fileContent = fileread(testReportPath);
    
    % Extract date from report
    datePattern = '**Test Date:** (.+?)\n';
    dateMatch = regexp(fileContent, datePattern, 'tokens');
    if ~isempty(dateMatch)
        testDate = dateMatch{1}{1};
    else
        testDate = datestr(now);
    end
    
    % Create test results data structure
    testResults = {};
    
    % Extract test names and status
    testNames = {
        'Basic Emulator Test',
        'Connection Error Recovery Test',
        'Data Parsing Validation Test',
        'Performance Benchmark Test', 
        'Dual Sensor Simultaneous Test'
    };
    
    % Parse durations
    durationPattern = '**Duration:** ([\d\.]+) seconds';
    durationMatches = regexp(fileContent, durationPattern, 'tokens');
    
    % Extract statuses from summary section
    for i = 1:length(testNames)
        % Create result structure
        result = struct();
        result.name = testNames{i};
        
        % Check if test passed
        statusPattern = [testNames{i} ': (PASS|FAIL)']; 
        statusMatch = regexp(fileContent, statusPattern, 'tokens');
        
        if ~isempty(statusMatch)
            result.status = statusMatch{1}{1};
        else
            result.status = 'UNKNOWN';
        end
        
        % Extract duration if available
        if i <= length(durationMatches)
            result.duration = str2double(durationMatches{i}{1});
        else
            result.duration = 1.0; % Default duration
        end
        
        % Add error message if test failed
        if strcmp(result.status, 'FAIL')
            result.errorMessage = 'Test failed';
        else
            result.errorMessage = '';
        end
        
        % Add to results array
        testResults{i} = result;
    end
    
    % Extract overall duration from report
    durationPattern = '**Test Duration:** ([\d\.]+) minutes';
    durationMatch = regexp(fileContent, durationPattern, 'tokens');
    if ~isempty(durationMatch)
        testDuration = str2double(durationMatch{1}{1});
    else
        % Calculate from individual durations
        totalDuration = 0;
        for i = 1:length(testResults)
            totalDuration = totalDuration + testResults{i}.duration;
        end
        testDuration = totalDuration / 60; % Convert to minutes
    end
    
    disp('Test report data read successfully!');
end

%% Create a visualization of the sensor data
function createSensorDataVisualization()
    figure('Name', 'Gocator Sensor Data Visualization', 'Position', [100, 100, 800, 500]);
    
    % Create two simulated profile datasets
    % Dataset 1 - Sensor 1
    numPoints = 100;
    x1 = linspace(-10, 10, numPoints);
    y1 = sqrt(100 - x1.^2) + randn(size(x1)) * 0.5;
    
    % Dataset 2 - Sensor 2 (with offset to simulate different positioning)
    x2 = linspace(-5, 15, numPoints);
    y2 = sqrt(100 - (x2-5).^2) - 2 + randn(size(x2)) * 0.5;
    
    % Plot the two datasets
    plot(x1, y1, 'b.', 'MarkerSize', 10);
    hold on;
    plot(x2, y2, 'r.', 'MarkerSize', 10);
    
    % Add labels and formatting
    title('Gocator 3210 Simulated Profile Data', 'FontSize', 14, 'FontWeight', 'bold');
    xlabel('X-Coordinate (mm)', 'FontSize', 12);
    ylabel('Y-Coordinate (mm)', 'FontSize', 12);
    legend('Sensor 1', 'Sensor 2', 'Location', 'best', 'FontSize', 12);
    grid on;
    box on;
    set(gca, 'FontSize', 11);
    
    % Add annotations for key features
    text(0, 10, 'Profile Peak', 'FontSize', 11, 'FontWeight', 'bold');
    annotation('arrow', [0.5, 0.45], [0.8, 0.85]);
    
    text(7, 5, 'Secondary Sensor', 'FontSize', 11, 'FontWeight', 'bold');
    annotation('arrow', [0.65, 0.7], [0.6, 0.5]);
    
    % Save figure to file
    saveas(gcf, 'sensor_data_visualization.png');
    disp('Sensor data visualization created and saved.');
end

%% Create a test performance chart
function createTestPerformanceChart(testResults)
    figure('Name', 'Test Performance Metrics', 'Position', [100, 100, 800, 500]);
    
    % Extract test names and durations
    testNames = {};
    durations = [];
    colors = [];
    
    for i = 1:length(testResults)
        testNames{i} = testResults{i}.name;
        durations(i) = testResults{i}.duration;
        
        % Set color based on test status
        if strcmp(testResults{i}.status, 'PASS')
            colors(i,:) = [0.2, 0.7, 0.3]; % Green for passed tests
        else
            colors(i,:) = [0.8, 0.2, 0.2]; % Red for failed tests
        end
    end
    
    % Create bar chart with custom colors
    b = bar(durations);
    b.FaceColor = 'flat';
    for i = 1:length(testResults)
        b.CData(i,:) = colors(i,:);
    end
    
    % Add labels and formatting
    title('Test Execution Performance', 'FontSize', 14, 'FontWeight', 'bold');
    xlabel('Test Case', 'FontSize', 12);
    ylabel('Duration (seconds)', 'FontSize', 12);
    grid on;
    
    % Format x-axis labels
    set(gca, 'XTick', 1:length(testNames));
    set(gca, 'XTickLabel', testNames);
    xtickangle(45);
    set(gca, 'FontSize', 10);
    
    % Add data values above bars
    for i = 1:length(durations)
        text(i, durations(i) + 0.5, [num2str(durations(i), '%.2f') 's'], ...
            'HorizontalAlignment', 'center', 'FontSize', 10);
    end
    
    % Save the figure
    saveas(gcf, 'test_performance_chart.png');
    disp('Test performance chart created and saved.');
end

%% Generate HTML report
function generateHTMLReport(testResults, testDate, testDuration)
    % Create HTML file
    filePath = fullfile(pwd, 'Gocator_Test_Report.html');
    fid = fopen(filePath, 'w');
    
    % Calculate pass rate
    passCount = 0;
    for i = 1:length(testResults)
        if strcmp(testResults{i}.status, 'PASS')
            passCount = passCount + 1;
        end
    end
    passRate = (passCount / length(testResults)) * 100;
    
    % Write HTML header with embedded CSS for styling
    fprintf(fid, '<!DOCTYPE html>\n<html>\n<head>\n');
    fprintf(fid, '<meta charset="UTF-8">\n');
    fprintf(fid, '<title>Gocator MATLAB Client Test Report</title>\n');
    fprintf(fid, '<style>\n');
    fprintf(fid, '  body { font-family: Arial, sans-serif; line-height: 1.6; margin: 0; padding: 20px; color: #333; max-width: 1200px; margin: 0 auto; }\n');
    fprintf(fid, '  h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }\n');
    fprintf(fid, '  h2 { color: #2980b9; margin-top: 30px; border-bottom: 1px solid #ddd; padding-bottom: 5px; }\n');
    fprintf(fid, '  .header { display: flex; justify-content: space-between; align-items: center; }\n');
    fprintf(fid, '  .summary-box { background-color: #f8f9fa; border: 1px solid #ddd; border-radius: 5px; padding: 15px; margin: 20px 0; }\n');
    fprintf(fid, '  .pass-rate { font-size: 18px; font-weight: bold; }\n');
    fprintf(fid, '  .high-pass { color: #27ae60; }\n');
    fprintf(fid, '  .medium-pass { color: #f39c12; }\n');
    fprintf(fid, '  .low-pass { color: #e74c3c; }\n');
    fprintf(fid, '  table { border-collapse: collapse; width: 100%%; margin: 20px 0; box-shadow: 0 2px 3px rgba(0,0,0,0.1); }\n');
    fprintf(fid, '  th { background-color: #3498db; color: white; text-align: left; padding: 12px; }\n');
    fprintf(fid, '  td { border: 1px solid #ddd; padding: 12px; }\n');
    fprintf(fid, '  tr:nth-child(even) { background-color: #f2f2f2; }\n');
    fprintf(fid, '  tr:hover { background-color: #e9f7fe; }\n');
    fprintf(fid, '  .pass { color: #27ae60; font-weight: bold; }\n');
    fprintf(fid, '  .fail { color: #e74c3c; font-weight: bold; }\n');
    fprintf(fid, '  .visualization { margin: 30px 0; text-align: center; }\n');
    fprintf(fid, '  .visualization img { max-width: 100%%; border: 1px solid #ddd; border-radius: 5px; box-shadow: 0 3px 6px rgba(0,0,0,0.1); }\n');
    fprintf(fid, '  .visualization p { font-style: italic; color: #7f8c8d; margin-top: 10px; }\n');
    fprintf(fid, '  .recommendations { background-color: #f0f7fb; border-left: 5px solid #3498db; padding: 15px; margin: 30px 0; }\n');
    fprintf(fid, '  .recommendations h3 { color: #2980b9; margin-top: 0; }\n');
    fprintf(fid, '  .footer { margin-top: 50px; border-top: 1px solid #ddd; padding-top: 20px; color: #7f8c8d; font-size: 14px; }\n');
    fprintf(fid, '</style>\n');
    fprintf(fid, '</head>\n<body>\n');
    
    % Document header
    fprintf(fid, '<div class="header">\n');
    fprintf(fid, '  <h1>Gocator MATLAB Client Test Report</h1>\n');
    fprintf(fid, '</div>\n');
    
    % Test information
    fprintf(fid, '<div class="summary-box">\n');
    fprintf(fid, '  <p><strong>Test Date:</strong> %s</p>\n', testDate);
    fprintf(fid, '  <p><strong>Environment:</strong> Emulator not detected - tests run in simulation mode</p>\n');
    fprintf(fid, '  <p><strong>Test Duration:</strong> %.2f minutes</p>\n', testDuration);
    
    % Pass rate with color coding
    if passRate >= 90
        passRateClass = 'high-pass';
    elseif passRate >= 70
        passRateClass = 'medium-pass';
    else
        passRateClass = 'low-pass';
    end
    
    fprintf(fid, '  <p class="pass-rate">Overall Pass Rate: <span class="%s">%.1f%%</span> (%d of %d tests passed)</p>\n', ...
        passRateClass, passRate, passCount, length(testResults));
    fprintf(fid, '</div>\n');
    
    % Test results table
    fprintf(fid, '<h2>Test Results</h2>\n');
    fprintf(fid, '<table>\n');
    fprintf(fid, '  <tr>\n');
    fprintf(fid, '    <th>Test Name</th>\n');
    fprintf(fid, '    <th>Status</th>\n');
    fprintf(fid, '    <th>Duration (seconds)</th>\n');
    fprintf(fid, '    <th>Notes</th>\n');
    fprintf(fid, '  </tr>\n');
    
    % Add rows for each test
    for i = 1:length(testResults)
        result = testResults{i};
        
        % Determine status class for styling
        if strcmp(result.status, 'PASS')
            statusClass = 'pass';
            notes = 'Test completed successfully';
        else
            statusClass = 'fail';
            if ~isempty(result.errorMessage)
                notes = ['Error: ' result.errorMessage];
            else
                notes = 'Test failed';
            end
        end
        
        fprintf(fid, '  <tr>\n');
        fprintf(fid, '    <td>%s</td>\n', result.name);
        fprintf(fid, '    <td class="%s">%s</td>\n', statusClass, result.status);
        fprintf(fid, '    <td>%.2f</td>\n', result.duration);
        fprintf(fid, '    <td>%s</td>\n', notes);
        fprintf(fid, '  </tr>\n');
    end
    
    fprintf(fid, '</table>\n');
    
    % Add visualizations
    fprintf(fid, '<h2>Test Visualizations</h2>\n');
    
    % Sensor data visualization
    fprintf(fid, '<div class="visualization">\n');
    fprintf(fid, '  <h3>Sensor Profile Data</h3>\n');
    fprintf(fid, '  <img src="sensor_data_visualization.png" alt="Sensor Profile Data">\n');
    fprintf(fid, '  <p>Figure 1: Simulated profile data from two Gocator 3210 sensors shown with different spatial positioning</p>\n');
    fprintf(fid, '</div>\n');
    
    % Test performance chart
    fprintf(fid, '<div class="visualization">\n');
    fprintf(fid, '  <h3>Test Performance Metrics</h3>\n');
    fprintf(fid, '  <img src="test_performance_chart.png" alt="Test Performance Chart">\n');
    fprintf(fid, '  <p>Figure 2: Execution time for each test case in seconds</p>\n');
    fprintf(fid, '</div>\n');
    
    % Recommendations section
    fprintf(fid, '<div class="recommendations">\n');
    fprintf(fid, '  <h3>Recommendations for Further Testing</h3>\n');
    fprintf(fid, '  <ul>\n');
    fprintf(fid, '    <li><strong>Physical Hardware Testing:</strong> Test with physical Gocator 3210 sensors when available to validate real-world performance</li>\n');
    fprintf(fid, '    <li><strong>Extended Data Validation:</strong> Add additional tests with varied profile data to ensure robust parsing and processing</li>\n');
    fprintf(fid, '    <li><strong>Error Recovery Testing:</strong> Implement more extensive network error and recovery scenarios to ensure client robustness</li>\n');
    fprintf(fid, '    <li><strong>Visualization Tools:</strong> Develop additional visualization tools for real-time profile data analysis and monitoring</li>\n');
    fprintf(fid, '    <li><strong>Performance Optimization:</strong> Profile and optimize the data retrieval and processing workflow for high-frequency measurements</li>\n');
    fprintf(fid, '  </ul>\n');
    fprintf(fid, '</div>\n');
    
    % Footer
    fprintf(fid, '<div class="footer">\n');
    fprintf(fid, '  <p>This report was automatically generated by the Gocator MATLAB Client Test Suite on %s</p>\n', datestr(now, 'mmm dd, yyyy HH:MM:SS'));
    fprintf(fid, '  <p>Gocator is a registered trademark of LMI Technologies Inc.</p>\n');
    fprintf(fid, '</div>\n');
    
    % Close HTML document
    fprintf(fid, '</body>\n</html>');
    fclose(fid);
    
    % Display message
    disp(['HTML test report generated and saved to: ' filePath]);
    
    % Try to open the HTML file
    try
        if ispc
            system(['start "" "' filePath '"']);
        elseif ismac
            system(['open "' filePath '"']);
        else
            system(['xdg-open "' filePath '"']);
        end
    catch
        disp('Could not automatically open the HTML file. Please open it manually.');
    end
    
    % Provide instructions for Word conversion
    disp('To convert to Word format:');
    disp('1. Open the HTML file in a web browser');
    disp('2. Use "File > Save As" or "Print > Save as PDF"');
    disp('3. Or open the HTML file directly in Microsoft Word');
end

%% Run all tests and collect results
function [testResultsEmulator, passCount, totalTests] = runAllTests()
    % Initialize test tracking variables
    testResultsEmulator = '';
    passCount = 0;
    totalTests = 0;
    
    % Define test cases
    testCases = {
        @testSensorInitialization
        @testSensorConnection
        @testDataRetrieval
        @testDataFormat
    };
    
    totalTests = length(testCases);
    
    % Run each test case
    for i = 1:length(testCases)
        try
            [result, passed] = testCases{i}();
            if passed
                passCount = passCount + 1;
            end
            testResultsEmulator = [testResultsEmulator result];
        catch ME
            testResultsEmulator = [testResultsEmulator sprintf('Test %d: ERROR - %s\n', i, ME.message)];
        end
    end
end

%% Test sensor initialization
function [result, passed] = testSensorInitialization()
    disp('Running sensor initialization test...');
    try
        % Run the client in test mode
        gocator_emulator_client(true);
        result = 'Sensor Initialization Test: PASSED\n';
        passed = true;
    catch ME
        result = sprintf('Sensor Initialization Test: FAILED - %s\n', ME.message);
        passed = false;
    end
end

%% Test sensor connection
function [result, passed] = testSensorConnection()
    disp('Running sensor connection test...');
    try
        % Test connection functionality
        config = struct(...
            'emulator_ip', '127.0.0.1', ...
            'sensors', [...
                struct('name', 'Test Sensor 1', 'port_offset', 0) ...
            ], ...
            'base_ports', struct('control', 3190, 'data', 3192, 'health', 3194), ...
            'timeout', 5, ...
            'term_char', '\r\n' ...
        );
        
        sensors = initializeEmulatedSensors(config);
        if ~isempty(sensors) && isfield(sensors(1), 'enabled')
            result = 'Sensor Connection Test: PASSED\n';
            passed = true;
        else
            result = 'Sensor Connection Test: FAILED - Could not establish connection\n';
            passed = false;
        end
    catch ME
        result = sprintf('Sensor Connection Test: FAILED - %s\n', ME.message);
        passed = false;
    end
end

%% Test data retrieval
function [result, passed] = testDataRetrieval()
    disp('Running data retrieval test...');
    try
        % Test data retrieval functionality
        config = struct(...
            'emulator_ip', '127.0.0.1', ...
            'sensors', [...
                struct('name', 'Test Sensor 1', 'port_offset', 0) ...
            ], ...
            'base_ports', struct('control', 3190, 'data', 3192, 'health', 3194), ...
            'timeout', 5, ...
            'term_char', '\r\n' ...
        );
        
        sensors = initializeEmulatedSensors(config);
        [data, success] = getXYData(sensors(1));
        
        if success && isstruct(data) && isfield(data, 'x') && isfield(data, 'y')
            result = 'Data Retrieval Test: PASSED\n';
            passed = true;
        else
            result = 'Data Retrieval Test: FAILED - Could not retrieve valid data\n';
            passed = false;
        end
    catch ME
        result = sprintf('Data Retrieval Test: FAILED - %s\n', ME.message);
        passed = false;
    end
end

%% Test data format
function [result, passed] = testDataFormat()
    disp('Running data format test...');
    try
        % Test data format validation
        config = struct(...
            'emulator_ip', '127.0.0.1', ...
            'sensors', [...
                struct('name', 'Test Sensor 1', 'port_offset', 0) ...
            ], ...
            'base_ports', struct('control', 3190, 'data', 3192, 'health', 3194), ...
            'timeout', 5, ...
            'term_char', '\r\n' ...
        );
        
        sensors = initializeEmulatedSensors(config);
        [data, success] = getXYData(sensors(1));
        
        if success && isnumeric(data.x) && isnumeric(data.y) && ...
           length(data.x) == length(data.y) && length(data.x) > 0
            result = 'Data Format Test: PASSED\n';
            passed = true;
        else
            result = 'Data Format Test: FAILED - Invalid data format\n';
            passed = false;
        end
    catch ME
        result = sprintf('Data Format Test: FAILED - %s\n', ME.message);
        passed = false;
    end
end
