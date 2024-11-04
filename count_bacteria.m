function bacteria_count = count_bacteria_auto_circle_enhanced(image_path)
    % Read the image
    img = imread(image_path);

    % Convert to grayscale if the image is in color
    if size(img, 3) == 3
        img_gray = rgb2gray(img);
    else
        img_gray = img;
    end

    % Strong contrast enhancement using adaptive histogram equalization
    img_enhanced = adapthisteq(img_gray, 'ClipLimit', 0.02, 'Distribution', 'rayleigh');

    imshow(img_enhanced)
    % Automatically detect a circle using imfindcircles
    % radiusRange = [400, 700]; % Adjust radius range as needed
    % [centers, radii] = imfindcircles(img_enhanced, radiusRange, 'Sensitivity', 0.95);

    % Check if a circle was found
    if isempty(centers)
        error('No circle detected with the specified radius range.');
    end

    % Use the first detected circle (assuming it's the petri dish)
    center = enters(1, :);
    radius = radii(1);

    % Display the detected circle on the original image for verification
    figure;
    imshow(img);
    hold on;
    viscircles(center, radius, 'EdgeColor', 'b');
    title('Detected Circle on Petri Dish');
    hold off;

    % Crop the image to the bounding box of the detected circle
    x_min = max(1, floor(center(1) - radius));
    x_max = min(size(img, 2), ceil(center(1) + radius));
    y_min = max(1, floor(center(2) - radius));
    y_max = min(size(img, 1), ceil(center(2) + radius));
    img_cropped = img_gray(y_min:y_max, x_min:x_max);

    % Create a circular mask for the cropped image
    [cropped_rows, cropped_cols] = size(img_cropped);
    [X, Y] = meshgrid(1:cropped_cols, 1:cropped_rows);
    X_centered = X - (center(1) - x_min);
    Y_centered = Y - (center(2) - y_min);
    circle_mask = (X_centered.^2 + Y_centered.^2) <= radius^2;

    % Apply the circular mask to the cropped image
    img_cropped_masked = img_cropped;
    img_cropped_masked(~circle_mask) = 0;

    % Step 1: Remove dark artifacts (e.g., black text) using threshold 155
    artifact_mask = img_cropped_masked < 155;  % Threshold of 155 to identify dark artifacts
    img_no_artifacts = img_cropped_masked;
    img_no_artifacts(artifact_mask) = 0;

    % Step 2: Enhance small colonies using adaptive thresholding with increased sensitivity
    img_blurred = imgaussfilt(img_no_artifacts, 1); % Slight blur to reduce noise
    colonies_mask = imbinarize(img_blurred, 'adaptive', 'ForegroundPolarity', 'dark', 'Sensitivity', 0.6);
    
    % Invert the binary image to make colonies white on black
    colonies_mask = ~colonies_mask;

    % Step 3: Refine with morphological operations to enhance clumps of colonies
    % Use morphological opening to remove noise
    se_open = strel('disk', 1); % Small structuring element
    colonies_mask = imopen(colonies_mask, se_open);

    % Use morphological closing with a larger structuring element to connect small colonies
    se_close = strel('disk', 3); % Larger structuring element for closing
    colonies_mask = imclose(colonies_mask, se_close);

    % Step 4: Size filtering to keep a broad range of colony sizes
    colonies_mask = bwareaopen(colonies_mask, 10); % Remove small noise
    colonies_mask = bwareafilt(colonies_mask, [5, 1000]); % Broader size range for clumps of colonies

    % Label connected components to count colonies
    labeled_img = bwlabel(colonies_mask);
    bacteria_count = max(labeled_img(:)); % Colony count

    % Display results
    figure;
    subplot(1, 4, 1), imshow(img), title('Original Image');
    subplot(1, 4, 2), imshow(img_no_artifacts), title('Image without Dark Artifacts');
    subplot(1, 4, 3), imshow(img_cropped_masked), title('Cropped and Masked Image');
    subplot(1, 4, 4), imshow(label2rgb(labeled_img, 'jet', 'k')), title(['Bacteria Count: ', num2str(bacteria_count)]);

    % Print the colony count to console
    fprintf('Estimated number of bacteria colonies within the circular region: %d\n', bacteria_count);
end
