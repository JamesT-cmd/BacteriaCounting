function bacteria_estimate_gui(image_path)
    % Global variables to store configuration settings
    global adjusted_radius_delta threshold_log circle_mask_cropped center adjusted_radius averageSizeField;
    global average_bacteria_area blueThresholdSlider;

    % Initialize threshold log to store direction and value for each threshold
    threshold_log = [];  % Struct array to store each threshold's direction and value
    
    % Main GUI window
    fig = uifigure('Name', 'Bacteria Estimation', 'Position', [100, 100, 1200, 600]);

    % Load and process the initial image
    img = imread(image_path);
    if size(img, 3) == 3
        img_rgb = img;  % Preserve the RGB image
        img_gray = rgb2gray(img);
    else
        img_rgb = cat(3, img, img, img); % Convert grayscale to RGB by replicating channels
        img_gray = img;
    end

    % Detect circle (petri dish) using advanced method
    radiusRange = [400, 700];
    [centers, radii] = advanced_circle_detection(img_gray, radiusRange);

    % Check if any circle was detected
    if isempty(centers)
        uialert(fig, 'No circle detected with the specified radius range.', 'Detection Error');
        return;
    end

    % Use the first detected circle (assuming it’s the petri dish)
    center = centers(1, :);
    initial_radius = radii(1); % Initial radius of detected circle

    % Set the initial radius and threshold values
    adjusted_radius = initial_radius;
    adjusted_radius_delta = 0;  % Change in radius from initial value
    
    % Crop the full image to the region of the detected circle
    x_min = max(1, floor(center(1) - initial_radius));
    x_max = min(size(img, 2), ceil(center(1) + initial_radius));
    y_min = max(1, floor(center(2) - initial_radius));
    y_max = min(size(img, 1), ceil(center(2) + initial_radius));
    img_cropped = img_gray(y_min:y_max, x_min:x_max);
    img_rgb_cropped = img_rgb(y_min:y_max, x_min:x_max, :);

    % Initialize the circle mask and working image
    circle_mask_cropped = []; % Initialize as empty, will be updated in updateCircleMask
    updateCircleMask(); % Initialize the circle mask based on the detected radius
    working_img = img_cropped; % Set the initial working image to the cropped image

    % Create Axes for displaying the original and thresholded images
    axOriginal = uiaxes(fig, 'Position', [50, 150, 500, 400]);
    axThresholded = uiaxes(fig, 'Position', [650, 150, 500, 400]);
    title(axOriginal, 'Current Image');
    title(axThresholded, 'Thresholded Image');

    % Display the initial cropped and masked original image
    showOriginalImage();

    % Add a label to display the processing status
    processingStatusLabel = uilabel(fig, 'Text', '', 'Position', [800, 90, 300, 30]);

    % Circle Radius Adjustment Slider
    uilabel(fig, 'Text', 'Circle Radius Adjustment', 'Position', [50, 130, 200, 20]);
    radiusSlider = uislider(fig, 'Limits', [initial_radius - 100, initial_radius + 100], ...
        'Value', initial_radius, 'Position', [250, 130, 200, 3], 'ValueChangedFcn', @(sld, event) adjustRadius());

    % Threshold Slider
    uilabel(fig, 'Text', 'Threshold', 'Position', [50, 50, 100, 20]);
    thresholdSlider = uislider(fig, 'Limits', [0, 255], 'Value', 128, ...
        'Position', [150, 50, 200, 3], 'ValueChangedFcn', @(sld, event) updateThresholdedImage());

    % Blue Threshold Slider
    uilabel(fig, 'Text', 'Blue Threshold', 'Position', [450, 130, 100, 20]);
    blueThresholdSlider = uislider(fig, 'Limits', [0, 255], 'Value', 128, ...
        'Position', [550, 130, 200, 3], 'ValueChangedFcn', @(sld, event) updateBlueThresholdedImage());

    % Direction Toggle Button
    directionToggleButton = uibutton(fig, 'state', 'Text', 'Threshold: Below', ...
        'Position', [450, 50, 150, 30], 'ValueChangedFcn', @(btn, event) toggleDirection());

    % Button to apply and subtract thresholded areas and log the threshold
    subtractButton = uibutton(fig, 'push', 'Text', 'Apply and Subtract', ...
        'Position', [620, 50, 150, 30], 'ButtonPushedFcn', @(btn, event) applyAndLogThreshold());

    % Text box to display the average colony size with default value 50
    uilabel(fig, 'Text', 'Average Colony Size (pixels)', 'Position', [50, 90, 200, 20]);
    averageSizeField = uieditfield(fig, 'numeric', 'Value', 50, 'Position', [250, 90, 60, 20], ...
        'ValueChangedFcn', @(fld, event) updateThresholdedImage());

    % Button to calculate average colony size
    selectPointsButton = uibutton(fig, 'push', 'Text', 'Select Colonies', ...
        'Position', [50, 170, 150, 30], 'ButtonPushedFcn', @(btn, event) calculateAverageColonySize());

    % Function to display the initial cropped and masked original image
    function showOriginalImage()
        img_cropped_masked = img_cropped;
        img_cropped_masked(~circle_mask_cropped) = 0;
        working_img = img_cropped_masked;

        imshow(working_img, 'Parent', axOriginal);
        viscircles(axOriginal, center - [x_min, y_min], adjusted_radius, 'EdgeColor', 'r');
    end

    % Function to update the blue-thresholded image display
    function updateBlueThresholdedImage()
        blue_threshold_value = blueThresholdSlider.Value;

        % Apply the blue threshold on the blue channel of the RGB cropped image
        blue_channel = img_rgb_cropped(:,:,3);
        blue_thresholded_img = blue_channel >= blue_threshold_value;
        blue_thresholded_img = blue_thresholded_img & circle_mask_cropped; % Mask outside the dish
        
        % Create a yellow overlay on areas that meet the blue threshold
        overlay_img = img_rgb_cropped;
        overlay_img(:,:,1) = overlay_img(:,:,1) + uint8(blue_thresholded_img) * 255; % Red channel for yellow
        overlay_img(:,:,2) = overlay_img(:,:,2) + uint8(blue_thresholded_img) * 255; % Green channel for yellow
        
        % Display the overlayed image on the original axes
        imshow(overlay_img, 'Parent', axOriginal);
        viscircles(axOriginal, center - [x_min, y_min], adjusted_radius, 'EdgeColor', 'r');
        title(axOriginal, sprintf('Blue Threshold = %d', blue_threshold_value));
    end

    % Function to update the circle mask based on adjusted radius
    function updateCircleMask()
        [cropped_rows, cropped_cols] = size(img_cropped);
        [X, Y] = meshgrid(1:cropped_cols, 1:cropped_rows);
        circle_mask_cropped = (X - (center(1) - x_min)).^2 + (Y - (center(2) - y_min)).^2 <= adjusted_radius^2;
    end

    % Function to adjust radius and update display
    function adjustRadius()
        adjusted_radius = radiusSlider.Value;
        adjusted_radius_delta = adjusted_radius - initial_radius;
        updateCircleMask();
        showOriginalImage();
        updateThresholdedImage();
    end

    % Function to toggle threshold direction and update immediately
    function toggleDirection()
        if directionToggleButton.Value
            directionToggleButton.Text = 'Threshold: Above';
        else
            directionToggleButton.Text = 'Threshold: Below';
        end
        updateThresholdedImage(); % Refresh thresholded image immediately
    end

    function calculateAverageColonySize()
        % Ensure that `working_img` has thresholded data for colony selection
        if isempty(working_img)
            disp('Error: Working image is empty.');
            return;
        end
    
        % Create a binary mask from `working_img` where values > 1 are considered colonies
        colony_masked_img = working_img > 1;
    
        % Convert the binary mask to an RGB image (white regions for colonies)
        colony_rgb_img = repmat(uint8(colony_masked_img) * 255, 1, 1, 3); % White RGB colonies
    
        % Open a UI figure to display the RGB thresholded image
        selectionFig = uifigure('Name', 'Select Colonies', 'Position', [100, 100, 600, 600]);
        axSelection = uiaxes(selectionFig, 'Position', [50, 50, 500, 500]);
        imgDisplay = imshow(colony_rgb_img, 'Parent', axSelection); % Show the RGB image
        title(axSelection, 'Click on colonies to select, then press "Calculate Average"');
        
        % Button to calculate the average colony size
        calculateButton = uibutton(selectionFig, 'Text', 'Calculate Average', ...
            'Position', [250, 20, 100, 30], 'ButtonPushedFcn', @calculateAverageSize);
    
        % Initialize list to store colony areas
        colony_areas = [];
    
        % Set up the mouse click callback directly on the image
        imgDisplay.ButtonDownFcn = @imageClickCallback;
    
        % Nested function to handle clicks on the image
        function imageClickCallback(~, ~)
            % Get the click point relative to the axes
            click_point = axSelection.CurrentPoint;
            x = round(click_point(1,1));
            y = round(click_point(1,2));
            
            % Ensure click is within bounds of the image
            if x < 1 || x > size(colony_masked_img, 2) || y < 1 || y > size(colony_masked_img, 1)
                uialert(selectionFig, 'Please click within the image bounds.', 'Out of Bounds');
                return;
            end
    
            % Select the connected component (colony) at the clicked location
            colony_mask = bwselect(colony_masked_img, x, y, 8); % Use binary mask for selection
            colony_area = sum(colony_mask(:)); % Calculate the area of the selected colony
            
            % Append the colony area to the list
            colony_areas = [colony_areas, colony_area];
    
            % Highlight the selected colony in yellow in the RGB image
            colony_rgb_img(:,:,1) = colony_rgb_img(:,:,1) .* uint8(~colony_mask) + uint8(colony_mask) * 255; % Red channel
            colony_rgb_img(:,:,2) = colony_rgb_img(:,:,2) .* uint8(~colony_mask) + uint8(colony_mask) * 255; % Green channel
            colony_rgb_img(:,:,3) = colony_rgb_img(:,:,3) .* uint8(~colony_mask); % Blue channel stays 0 for yellow
    
            % Update the displayed image in `axSelection`
            imgDisplay.CData = colony_rgb_img;
            drawnow;
        end
    
        % Function to calculate and display the average colony size
        function calculateAverageSize(~, ~)
            if isempty(colony_areas)
                uialert(selectionFig, 'No colonies selected. Please select colonies first.', 'No Selection');
                return;
            end
            
            % Calculate the average colony area
            average_bacteria_area = mean(colony_areas);
            averageSizeField.Value = average_bacteria_area; % Update the average size field in the main GUI
            
            % Close the selection figure
            close(selectionFig);
            
            % Update the main GUI with the new estimated colony count
            updateThresholdedImage();
        end
    end
    

    % Function to update the thresholded image display
    function updateThresholdedImage()
        threshold_value = thresholdSlider.Value;
        if directionToggleButton.Value
            threshold_direction = 'above';
        else
            threshold_direction = 'below';
        end

        if strcmp(threshold_direction, 'below')
            thresholded_img = working_img < threshold_value;
        else
            thresholded_img = working_img > threshold_value;
        end
        thresholded_img = thresholded_img & circle_mask_cropped;

        total_colony_area = sum(thresholded_img(:));
        average_bacteria_area = averageSizeField.Value;
        if average_bacteria_area > 0
            estimated_colony_count = round(total_colony_area / average_bacteria_area);
        else
            estimated_colony_count = 0;
        end

        imshow(thresholded_img, 'Parent', axThresholded);
        title(axThresholded, sprintf('Thresholded Image - Estimated Colony Count: %d', estimated_colony_count));
    end

    % Function to log and apply a threshold when user clicks "Apply and Subtract"
    function applyAndLogThreshold()
        threshold_value = thresholdSlider.Value;
        threshold_direction = 'below';
        if directionToggleButton.Value
            threshold_direction = 'above';
        end

        threshold_log = [threshold_log; struct('value', threshold_value, 'direction', threshold_direction)];

        if strcmp(threshold_direction, 'below')
            thresholded_img = working_img < threshold_value;
        else
            thresholded_img = working_img > threshold_value;
        end
        thresholded_img = thresholded_img & circle_mask_cropped;
        working_img(thresholded_img) = 0;

        imshow(working_img, 'Parent', axOriginal);
        viscircles(axOriginal, center - [x_min, y_min], adjusted_radius, 'EdgeColor', 'r');
        title(axOriginal, 'Current Image with Subtracted Areas');
        updateThresholdedImage();
    end

    function batchProcessImages()
        % Prompt the user to select a folder
        folder_path = uigetdir;
        if folder_path == 0
            disp('Batch processing canceled.');
            return;
        end
        
        % Define the subfolder for saving processed images
        processed_folder = fullfile(folder_path, 'processed_images');
        if ~exist(processed_folder, 'dir')
            mkdir(processed_folder); % Create the folder if it doesn't exist
        end
        
        % List all files in the folder (no extension restriction)
        files = dir(fullfile(folder_path, '*.*'));
        files = files(~[files.isdir]); % Exclude directories
    
        % Check if `average_bacteria_area` and thresholds are set
        if isempty(average_bacteria_area) || average_bacteria_area <= 0
            processingStatusLabel.Text = 'Error: Set average colony size first.';
            drawnow;
            return;
        elseif isempty(threshold_log)
            processingStatusLabel.Text = 'Error: Apply at least one threshold.';
            drawnow;
            return;
        end
    
        % Update the status label to show that processing has started
        processingStatusLabel.Text = ['Processing images in folder: ', folder_path];
        drawnow;
    
        % Process each image file
        for file = files'
            try
                % Update label to show the current file being processed
                processingStatusLabel.Text = ['Processing: ', file.name];
                drawnow;
    
                % Load the image
                img = imread(fullfile(file.folder, file.name));
                if size(img, 3) == 3
                    img_rgb = img; % Keep the original color image
                    img_gray = rgb2gray(img);
                else
                    img_rgb = cat(3, img, img, img); % Convert grayscale to RGB by replicating channels
                    img_gray = img;
                end
                
                % Detect the Petri dish circle (center and radius)
                [centers, radii] = advanced_circle_detection(img_gray, radiusRange);
                if isempty(centers)
                    warning(['No circle detected in image: ', file.name]);
                    continue; % Skip if no circle is detected
                end
                
                % Use the first detected circle
                center = centers(1, :);
                radius = radii(1) + adjusted_radius_delta;
                
                % Crop to the detected circular region
                x_min = max(1, floor(center(1) - radius));
                x_max = min(size(img, 2), ceil(center(1) + radius));
                y_min = max(1, floor(center(2) - radius));
                y_max = min(size(img, 1), ceil(center(2) + radius));
                img_cropped = img_gray(y_min:y_max, x_min:x_max);
                img_rgb_cropped = img_rgb(y_min:y_max, x_min:x_max, :);
    
                % Initialize the circular mask for the cropped image
                [X, Y] = meshgrid(1:size(img_cropped, 2), 1:size(img_cropped, 1));
                circle_mask = (X - (center(1) - x_min)).^2 + (Y - (center(2) - y_min)).^2 <= radius^2;
    
                % Apply the circular mask to remove areas outside the Petri dish
                working_img = img_cropped;
                working_img(~circle_mask) = 0;  % Set outside-circle regions to zero
    
                % Initialize a binary image for colony areas
                final_binary_img = false(size(working_img));
    
                % Apply each logged threshold in order
                for i = 1:length(threshold_log)
                    threshold_value = threshold_log(i).value;
                    threshold_direction = threshold_log(i).direction;
    
                    % Apply the threshold based on direction
                    if strcmp(threshold_direction, 'below')
                        thresholded_img = working_img < threshold_value;
                    else
                        thresholded_img = working_img > threshold_value;
                    end
    
                    % Restrict the thresholded image to the circular region
                    thresholded_img = thresholded_img & circle_mask;
    
                    % Accumulate thresholded results into final_binary_img
                    final_binary_img = final_binary_img | thresholded_img;
    
                    % Set thresholded regions in `working_img` to zero for further processing
                    working_img(thresholded_img) = 0;
                end
    
                % Invert the final binary image so colonies are represented as 1s
                final_binary_img = ~final_binary_img & circle_mask; % Invert and apply circle mask
    
                % Calculate colony count
                total_colony_area = sum(final_binary_img(:));
                estimated_colony_count = round(total_colony_area / average_bacteria_area);
    
                % Apply the binary mask to the RGB image to isolate colony regions
                masked_rgb_img = img_rgb_cropped;
                masked_rgb_img(repmat(~final_binary_img, [1 1 3])) = 0; % Set non-colony pixels to zero
    
                % Extract R, G, and B values within the masked colony regions
                r_values = masked_rgb_img(:,:,1);
                g_values = masked_rgb_img(:,:,2);
                b_values = masked_rgb_img(:,:,3);
    
                % Filter out zero (non-colony) pixels and create histograms
                r_values = r_values(r_values > 0);
                g_values = g_values(g_values > 0);
                b_values = b_values(b_values > 0);
    
                % Calculate histograms with bins from 1 to 255 for each channel
                [r_counts, r_bins] = histcounts(r_values, 1:256);
                [g_counts, g_bins] = histcounts(g_values, 1:256);
                [b_counts, b_bins] = histcounts(b_values, 1:256);
    
                % Display the results in a figure with four subplots
                figure;
                
                % Subplot 1: Original Image with Circle and Colony Count
                subplot(2, 2, 1);
                imshow(img_rgb); hold on;
                viscircles(center, radius, 'EdgeColor', 'b'); % Draw circle on original image
                title(['Original Image: ', file.name, ' - Colony Count: ', num2str(estimated_colony_count)]);
    
                % Subplot 2: Red Channel Intensity Distribution
                subplot(2, 2, 2);
                bar(r_bins(1:end-1), r_counts, 'r');
                title('Red Channel Intensity Distribution');
                xlabel('Intensity Value');
                ylabel('Count');
    
                % Subplot 3: Green Channel Intensity Distribution
                subplot(2, 2, 3);
                bar(g_bins(1:end-1), g_counts, 'g');
                title('Green Channel Intensity Distribution');
                xlabel('Intensity Value');
                ylabel('Count');
    
                % Subplot 4: Blue Channel Intensity Distribution
                subplot(2, 2, 4);
                bar(b_bins(1:end-1), b_counts, 'b');
                title('Blue Channel Intensity Distribution');
                xlabel('Intensity Value');
                ylabel('Count');
    
                % Save the processed figure as a JPEG in the new folder
                save_path = fullfile(processed_folder, ['processed_' file.name '.jpg']);
                saveas(gcf, save_path, 'jpeg');
                close;
                
            catch ME
                warning(['Failed to process image: ', file.name, '. Error: ', ME.message]);
                processingStatusLabel.Text = ['Error processing: ', file.name];
                drawnow;
            end
        end
    
        % Show completion message
        processingStatusLabel.Text = 'Batch processing completed.';
        disp('Batch processing completed.');
    end
end      
    % Advanced circle detection function
    function [centers, radii] = advanced_circle_detection(img_gray, radiusRange)
        img_enhanced = adapthisteq(img_gray, 'ClipLimit', 0.02, 'Distribution', 'rayleigh');
        scaleFactor = 0.5;
        img_small = imresize(img_enhanced, scaleFactor);
        img_blurred = imgaussfilt(img_small, 2);
        edges = edge(img_blurred, 'Canny', [0.08, 0.15]);
        scaledRadiusRange = radiusRange * scaleFactor;
        [centers, radii] = imfindcircles(edges, scaledRadiusRange, 'Sensitivity', 0.9, 'EdgeThreshold', 0.1);

        if isempty(centers)
            bw = imfill(edges, 'holes');
            stats = regionprops(bw, 'Centroid', 'EquivDiameter', 'Circularity');
            circularRegions = stats([stats.Circularity] > 0.7);
            circularRegions = circularRegions([circularRegions.EquivDiameter] / 2 >= scaledRadiusRange(1) & ...
                                              [circularRegions.EquivDiameter] / 2 <= scaledRadiusRange(2));
            if ~isempty(circularRegions)
                centers = cat(1, circularRegions.Centroid) / scaleFactor;
                radii = [circularRegions.EquivDiameter] / (2 * scaleFactor);
            else
                centers = [];
                radii = [];
            end
        else
            centers = centers / scaleFactor;
            radii = radii / scaleFactor;
        end
    end    
