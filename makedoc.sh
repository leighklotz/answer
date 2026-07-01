for cmd in answer ask bx help-commit help unfence; do
    # 1. Determine if the source is a standalone script or a function in functions.sh
    if [ -f "${cmd}.sh" ]; then
        SRC="${cmd}.sh"
    elif grep -qE "^(function )?${cmd}(\s*\(|\s*\{)" functions.sh 2>/dev/null; then
        SRC="functions.sh"
    else
        SRC=""
    fi

    # 2. Prepare destination directory
    DEST="doc/${cmd}.md"
    mkdir -p doc

    # 3. Construct arguments for lx: [Source File] + Context Files
    # Using an array prevents passing an empty string as an argument if SRC is empty
    CTX_ARGS=()
    [ -n "$SRC" ] && CTX_ARGS+=("$SRC")
    CTX_ARGS+=(README.md tests/story-test.sh doc/*.md)

    # 4. Run the pipeline to generate documentation
    lx "${CTX_ARGS[@]}" | help "document the $cmd command for $DEST" | unfence > "$DEST"
done
