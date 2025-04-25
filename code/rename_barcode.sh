#!/bin/bash
## For some reason it keeps adding in correct endlines
## the following lines fixes those
#sed -i 's/\r$//' ./code/rename_barcode.sh

## set folder
source_folder="$1"          # folder where the images are stored
destination_folder="$2"     # folder where the processed images are stored
pattern="$3"                # pattern to match the files in the folder
GM_settings="$4"          # optional: override default ImageMagick settings

#source_folder=$(wslpath "$source_folder")
#destination_folder=$(wslpath "$destination_folder")


# Check if the source folder is provided
if [ -z "$source_folder" ]; then
    echo "Please provide a valid the source folder as the first argument"
    exit 1
fi #end of source folder check

# Check if the destination folder is provided
if [ -z "$destination_folder" ]; then
    echo "Please provide a valid the destination folder as the second argument"
    exit 1
fi #end of destination folder check

# Check if the pattern is provided
if [ -z "$pattern" ]; then
    echo "Please provide a valid the pattern as the third argument"
    exit 1
fi  #end of pattern check

echo "The source folder is  $source_folder"
echo "The destination folder is  $destination_folder"
echo "The pattern is  $pattern"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"  # Move up one level

ZBAR_PATH="$PROJECT_ROOT/bin/ZBar/bin/zbarimg.exe"
GM_PATH="/usr/bin/gm"

# Check if the ImageMagick command-line tool exists
if [ ! -f "$GM_PATH" ]; then
    echo "The ImageMagick command-line tool was not found at $GM_PATH"
    exit 1
fi  #end of ImageMagick check


# Check if the ZBar command-line tool exists
if [ ! -f "$ZBAR_PATH" ]; then
    echo "The ZBar command-line tool was not found at $ZBAR_PATH"
    exit 1
fi  #end of ZBar check

# Check if the renamed and failed folders exist
# If not, create them
for subfolder in "$destination_folder" \
    "$destination_folder/renamed" \
    "$destination_folder/failed" \
    "$destination_folder/failed_processed"; do 
    if [ ! -d "$subfolder" ]; then
        mkdir -p "$subfolder"
        echo "Created directory: $subfolder"
    fi  #end of subfolder check/creation
done    #end of for loop for subfolders

## finding all files that match the pattern
# Get a list of all matching files for counting
shopt -s nullglob
all_files=("$source_folder"$pattern)
shopt -u nullglob
total_files="${#all_files[@]}"
processed_count=0

total_files="${#all_files[@]}"

# Process the files in the source folder
for file in "$source_folder"$pattern; do
    
    if [ -f "$file" ]; then
        # Process the files in the source folder
        filename=$(basename "$file")
            # keep track of the number of processed files
            processed_count=$((processed_count + 1))
            percentage=$(( (processed_count * 100) / total_files ))
                   # Convert the image and save it to a temporary file
            # Create a unique temporary file

    temp_file=$(mktemp "$destination_folder/temp.XXXXXX.jpg")
    if [ -z "$temp_file" ]; then
      echo "Error: Could not create a temporary file!"
      continue
    fi

    # Default ImageMagick settings
    #default_GM_settings=(-colorspace Gray -normalize -level 20%,80% -threshold 50%)
 #   default_GM_settings=(-colorspace Gray -contrast -threshold 50%)
    default_GM_settings=(
  -colorspace Gray
  -normalize
  -sharpen 0x1
  -adaptive-threshold 160x160+10%
  -resize 200%
)
    

    # Determine whether to use a settings file or inline settings
    if [ -z "$GM_settings" ]; then
      GM_settings=("${default_GM_settings[@]}")
      elif [ -f "$GM_settings" ]; then
      # Read settings from file and split into array (assuming space-separated)S
      read -ra GM_settings <<< "$(<"$GM_settings")"
      else
      # Split inline settings string into array (assuming space-separated)
      read -ra GM_settings <<< "$GM_settings"
    fi

    #default_GM_settings=(-colorspace Gray -normalize -level 20%,80% -threshold 50%)
    # Convert the image and save it to a temporary file
   #"$GM_PATH" convert "$file" "${GM_settings[@]}" -format JPEG "$temp_file" 2>&1
   #"$GM_PATH" convert "$file" "$default_GM_settings" -format JPEG "$temp_file" 2>&1
   # Default GraphicsMagick settings as a single string
   # Default GraphicsMagick settings array
   # Convert the image and save it to a temporary file  
    "$GM_PATH" convert "$file" "${default_GM_settings[@]}" -format JPEG "$temp_file" 
   
    #"$GM_PATH" convert "$file" -colorspace Gray -normalize -level 20%,80% -threshold 50% -format JPEG "$temp_file" 2>&1

 #      convert_exit_code="$?"
 #   if [ "$convert_exit_code" -ne 0 ]; then
 #     echo "Error during gm convert for $file (exit code $convert_exit_code):"
 #     # Optionally, echo the error message from gm
 #     # echo "$output"
 #     rm -f "$temp_file" # Ensure temp file is cleaned up on error
 #     continue # Skip to the next file
 #   fi


   # Check if the temporary file was created successfully
   if [ ! -f "$temp_file" ]; then
        echo "Error: $temp_file was not created!"
        exit 1
     fi

    # Read the barcode from the temporary file
    # using the ZBar command-line tool
    # --raw: output the barcode data only
    # --quiet: suppress the output of the filename
    name=$("$ZBAR_PATH"  --raw --quiet -Sdisable -Scode128.enable $temp_file)

    # If a barcode was found, rename the file
    if [ -n "$name" ]; then
        # Remove possible spaces from the barcode
        sanitized_name=$(echo "$name" | tr -d '[:space:]') 
        # rename the file to the barcode
        echo -ne "Renaming $file to $sanitized_name.jpg ($processed_count/$total_files; $percentage%)...\r"
        # copy the renamed file to the renamed folder
        cp "$file" "$destination_folder/renamed/$sanitized_name.jpg" 
        else    # If no barcode was found, move the file to the failed folder
        echo "No barcode found in $file"
        cp "$file" "$destination_folder/failed/$(basename "$file")"
         # For failed images, save the processed version for inspection
         processed_failed_file="$destination_folder/failed_processed/$(basename "$file")"
         "$GM_PATH" convert "$file" "${default_GM_settings[@]}" -format JPEG "$processed_failed_file"
         #echo "Saved processed failed image to: $processed_failed_file"
    fi #end of barcode check

        # Remove the temporary file
    rm -f "$temp_file"
   
    else
        echo "No files found with pattern $pattern"
        ls "$source_folder"
        exit 1
    fi  #end of file check
done

echo "" # Add a newline after the loop finishes
echo "Processing complete. $processed_count files processed."