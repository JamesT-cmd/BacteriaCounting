function edge_detection_with_sliders(image_path)
    % Load the image
    img = imread(image_path);
    if size(img, 3) == 3
        img_gray = rgb2gray(img); % Convert to grayscale if the image is in color
    else
        img_gray = img;
    end

    % Create a figure with UI components
    fig = uifigure('Name', 'Canny Edge Detection', 'Position', [100, 100, 800, 600]);

    % Create axes for displaying the edge-detected image
    ax = uiaxes(fig, 'Position', [100, 150, 600, 400]);
    title(ax, 'Canny Edge Detection');

    % Initial threshold values
    lowerThreshold = 0.1;
    upperThreshold = 0.3;

    % Display the initial edge-detected image
    showEdges(img_gray, ax, lowerThreshold, upperThreshold);

    % Lower Threshold Slider
    uilabel(fig, 'Position', [50, 80, 100, 22], 'Text', 'Lower Threshold');
    lowerSlider = uislider(fig, ...
        'Position', [150, 80, 200, 3], ...
        'Limits', [0, 1], ...
        'Value', lowerThreshold, ...
        'ValueChangedFcn', @(sld, event) updateEdgeImage());

    % Upper Threshold Slider
    uilabel(fig, 'Position', [400, 80, 100, 22], 'Text', 'Upper Threshold');
    upperSlider = uislider(fig, ...
        'Position', [500, 80, 200, 3], ...
        'Limits', [0, 1], ...
        'Value', upperThreshold, ...
        'ValueChangedFcn', @(sld, event) updateEdgeImage());

    % Callback function to update the edge-detected image
    function updateEdgeImage()
        lowerThreshold = lowerSlider.Value;
        upperThreshold = upperSlider.Value;
        showEdges(img_gray, ax, lowerThreshold, upperThreshold);
    end

end

% Helper function to apply Canny edge detection and display the result
function showEdges(img, ax, lowerThreshold, upperThreshold)
    edges = edge(img, 'Canny', [lowerThreshold, upperThreshold]);
    imshow(edges, 'Parent', ax);
    title(ax, sprintf('Canny Edge Detection - Lower: %.2f, Upper: %.2f', lowerThreshold, upperThreshold));
end
