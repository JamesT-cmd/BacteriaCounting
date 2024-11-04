function bacteria_gui(image_path)
    % Main GUI window
    fig = uifigure('Name', 'Bacteria Analysis', 'Position', [100, 100, 1200, 600]);

    % Load and process the initial image
    img = imread(image_path);
    if size(img, 3) == 3
        img_gray = rgb2gray(img);
    else
        img_gray = img;
    end

    % Enhance contrast
    img_enhanced = adapthisteq(img_gray, 'ClipLimit', 0.02, 'Distribution', 'rayleigh');

    % % Detect circle (petri dish)
    % radiusRange = [400, 700];
    % [centers, radii] = imfindcircles(img_enhanced, radiusRange, 'Sensitivity', 0.95);
    % if isempty(centers)
    %     uialert(fig, 'No circle detected with the specified radius range.', 'Detection Error');
    %     return;
    % end
    center = 1.0e+03 * [2.6543 1.0649] %centers(1, :);
    radius = 573.5920 %radii(1);

    % Create Axes for displaying the original and processed images
    axOriginal = uiaxes(fig, 'Position', [50, 150, 500, 400]);
    axProcessed = uiaxes(fig, 'Position', [600, 150, 500, 400]);
    title(axOriginal, 'Original Image');
    title(axProcessed, 'Processed Image');

    % Sliders and labels for element sizes, sensitivity, and size range
    % Sensitivity Slider
    uilabel(fig, 'Text', 'Sensitivity', 'Position', [50, 50, 100, 20]);
    sensitivitySlider = uislider(fig, 'Limits', [0.1, 1], 'Value', 0.6, ...
        'Position', [150, 50, 200, 3], 'ValueChangedFcn', @(sld, event) updateImage());
    sensitivityValue = uilabel(fig, 'Text', num2str(sensitivitySlider.Value, '%.2f'), 'Position', [370, 50, 40, 20]);

    % Opening Element Size Slider
    uilabel(fig, 'Text', 'Opening Element Size', 'Position', [50, 90, 150, 20]);
    openingSlider = uislider(fig, 'Limits', [1, 10], 'Value', 1, ...
        'Position', [150, 90, 200, 3], 'ValueChangedFcn', @(sld, event) updateImage());
    openingValue = uilabel(fig, 'Text', num2str(openingSlider.Value, '%.0f'), 'Position', [370, 90, 40, 20]);

    % Closing Element Size Slider
    uilabel(fig, 'Text', 'Closing Element Size', 'Position', [50, 130, 150, 20]);
    closingSlider = uislider(fig, 'Limits', [1, 10], 'Value', 3, ...
        'Position', [150, 130, 200, 3], 'ValueChangedFcn', @(sld, event) updateImage());
    closingValue = uilabel(fig, 'Text', num2str(closingSlider.Value, '%.0f'), 'Position', [370, 130, 40, 20]);

    % Size Range (Min) Slider
    uilabel(fig, 'Text', 'Size Range Min', 'Position', [50, 170, 150, 20]);
    sizeRangeSliderMin = uislider(fig, 'Limits', [1, 500], 'Value', 5, ...
        'Position', [150, 170, 200, 3], 'ValueChangedFcn', @(sld, event) updateImage());
    sizeRangeMinValue = uilabel(fig, 'Text', num2str(sizeRangeSliderMin.Value, '%.0f'), 'Position', [370, 170, 40, 20]);

    % Size Range (Max) Slider
    uilabel(fig, 'Text', 'Size Range Max', 'Position', [50, 210, 150, 20]);
    sizeRangeSliderMax = uislider(fig, 'Limits', [500, 2000], 'Value', 1000, ...
        'Position', [150, 210, 200, 3], 'ValueChangedFcn', @(sld, event) updateImage());
    sizeRangeMaxValue = uilabel(fig, 'Text', num2str(sizeRangeSliderMax.Value, '%.0f'), 'Position', [370, 210, 40, 20]);

    % Initial display of the original image
    showOriginalImage();

    % Update the displayed values and processed image based on slider input
    function updateImage()
        % Update display values next to sliders
        sensitivityValue.Text = num2str(sensitivitySlider.Value, '%.2f');
        openingValue.Text = num2str(openingSlider.Value, '%.0f');
        closingValue.Text = num2str(closingSlider.Value, '%.0f');
        sizeRangeMinValue.Text = num2str(sizeRangeSliderMin.Value, '%.0f');
        sizeRangeMaxValue.Text = num2str(sizeRangeSliderMax.Value, '%.0f');

        % Process the image using the current slider values
        sensitivity = sensitivitySlider.Value;
        openSize = round(openingSlider.Value);
        closeSize = round(closingSlider.Value);
        sizeRangeMin = round(sizeRangeSliderMin.Value);
        sizeRangeMax = round(sizeRangeSliderMax.Value);

        % Crop and mask based on the detected circle
        x_min = max(1, floor(center(1) - radius));
        x_max = min(size(img, 2), ceil(center(1) + radius));
        y_min = max(1, floor(center(2) - radius));
        y_max = min(size(img, 1), ceil(center(2) + radius));
        img_cropped = img_gray(y_min:y_max, x_min:x_max);

        % Create circular mask for the cropped image
        [cropped_rows, cropped_cols] = size(img_cropped);
        [X, Y] = meshgrid(1:cropped_cols, 1:cropped_rows);
        X_centered = X - (center(1) - x_min);
        Y_centered = Y - (center(2) - y_min);
        circle_mask = (X_centered.^2 + Y_centered.^2) <= radius^2;
        img_cropped_masked = img_cropped;
        img_cropped_masked(~circle_mask) = 0;

        % Remove dark artifacts
        artifact_mask = img_cropped_masked < 155;
        img_no_artifacts = img_cropped_masked;
        img_no_artifacts(artifact_mask) = 0;

        % Enhance small colonies using adaptive thresholding
        img_blurred = imgaussfilt(img_no_artifacts, 1); % Slight blur
        colonies_mask = imbinarize(img_blurred, 'adaptive', 'ForegroundPolarity', 'dark', 'Sensitivity', sensitivity);
        colonies_mask = ~colonies_mask; % Invert to make colonies white on black

        % Morphological operations
        se_open = strel('disk', openSize); % Structuring element for opening
        colonies_mask = imopen(colonies_mask, se_open);
        se_close = strel('disk', closeSize); % Structuring element for closing
        colonies_mask = imclose(colonies_mask, se_close);

        % Size filtering
        colonies_mask = bwareaopen(colonies_mask, 10);
        colonies_mask = bwareafilt(colonies_mask, [sizeRangeMin, sizeRangeMax]);

        % Label connected components
        labeled_img = bwlabel(colonies_mask);
        bacteria_count = max(labeled_img(:)); % Colony count

        % Display the processed image with colony count
        imshow(label2rgb(labeled_img, 'jet', 'k'), 'Parent', axProcessed);
        title(axProcessed, ['Bacteria Count: ', num2str(bacteria_count)]);
    end

    % Display the initial cropped and masked image
    function showOriginalImage()
        % Crop the image based on the detected circle
        x_min = max(1, floor(center(1) - radius));
        x_max = min(size(img, 2), ceil(center(1) + radius));
        y_min = max(1, floor(center(2) - radius));
        y_max = min(size(img, 1), ceil(center(2) + radius));
        img_cropped = img_gray(y_min:y_max, x_min:x_max);

        % Create circular mask for the cropped image
        [cropped_rows, cropped_cols] = size(img_cropped);
        [X, Y] = meshgrid(1:cropped_cols, 1:cropped_rows);
        X_centered = X - (center(1) - x_min);
        Y_centered = Y - (center(2) - y_min);
        circle_mask = (X_centered.^2 + Y_centered.^2) <= radius^2;
        img_cropped_masked = img_cropped;
        img_cropped_masked(~circle_mask) = 0;

        % Show the cropped and masked original image
        imshow(img_cropped_masked, 'Parent', axOriginal);
    end

    % Initial image update
    updateImage();
end
