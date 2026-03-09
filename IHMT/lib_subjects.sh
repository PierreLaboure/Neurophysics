load_subjects() {
    local config_file="$1"
    #config_file="./config.json"
    local subject_info_json=$(jq -r .subject_info "$config_json")

    # Ensure files exist
    [ -f "$config_file" ] || { echo "Config file not found: $config_file"; exit 1; }
    [ -f "$subject_info_json" ] || { echo "Subject info file not found: $subject_info_json"; exit 1; }

    mode=$(jq -r '.subject_selection.mode' "$config_file")

    case "$mode" in
        list)
            # Load requested subjects
            mapfile -t requested_subjects < <(jq -r '.subject_selection.subjects[]' "$config_file")

            subjects_list=()

            for subj in "${requested_subjects[@]}"; do
                if jq -e --arg s "$subj" '.[$s]' "$subject_info_json" > /dev/null; then
                    subjects_list+=("$subj")
                else
                    echo "Warning: $subj not found in subject_info.json — skipping"
                fi
            done
            ;;

        all)
            # Load ALL first-level keys from subject_info.json
            mapfile -t subjects_list < <(jq -r 'keys[]' "$subject_info_json")
            ;;

        *)
            echo "Unknown subject selection mode: $mode"
            exit 1
            ;;
    esac

    if [ ${#subjects_list[@]} -eq 0 ]; then
        echo "No subjects selected."
        exit 1
    fi
}
