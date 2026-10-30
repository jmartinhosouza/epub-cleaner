#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(pwd)"
STYLESHEET="$SCRIPT_DIR/stylesheet.css"
XSLT="$SCRIPT_DIR/opf.xsl"
TMP=""

cleanup() {
    if [[ -n "${TMP:-}" ]]; then
        rm -rf -- "$TMP"
        TMP=""
    fi
}

trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

for command in unzip zip xmlstarlet perl magick python3; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Error: command '$command' not found." >&2
        exit 1
    fi
done

if [[ ! -f "$STYLESHEET" ]]; then
    echo "Error: stylesheet.css not found in $SCRIPT_DIR." >&2
    exit 1
fi

if [[ ! -f "$XSLT" ]]; then
    echo "Error: opf.xsl not found in $SCRIPT_DIR." >&2
    exit 1
fi

process_epub() {
    local EPUB="$1"
    local TITLE
    local AUTHOR
    local LANGUAGE
    local OPF_REL
    local OPF
    local OPF_DIR
    local WORK
    local OUTPUT
    local CSS_DIR
    local CSS_FILE
    local CSS_HREF
    local COVER_DIR
    local COVER
    local COVER_HREF
    local XHTML
    local XHTML_DIR
    local XHTML_CSS_HREF
    local TMP_OPF
    local IDENTIFIER
    local MODIFIED

    echo
    echo "Processing: $EPUB"

    if ! read -r -p "Title: " TITLE </dev/tty; then
        echo "Could not read title from terminal." >&2
        return 1
    fi

    if ! read -r -p "Author: " AUTHOR </dev/tty; then
        echo "Could not read author from terminal." >&2
        return 1
    fi

    if [[ -z "$TITLE" || -z "$AUTHOR" ]]; then
        echo "Title and author cannot be empty. Skipping."
        return 1
    fi

    TMP="$(mktemp -d)"
    WORK="$TMP/epub"
    OUTPUT="$TMP/output.epub"

    mkdir -p "$WORK"

    echo "Extracting..."

    if ! unzip -q "$EPUB" -d "$WORK"; then
        echo "Error: could not extract EPUB." >&2
        return 1
    fi

    if [[ ! -f "$WORK/mimetype" ]]; then
        echo "Error: EPUB does not contain the mimetype file." >&2
        return 1
    fi

    if [[ ! -f "$WORK/META-INF/container.xml" ]]; then
        echo "Error: META-INF/container.xml not found." >&2
        return 1
    fi

    OPF_REL="$(
        xmlstarlet sel \
            -N c="urn:oasis:names:tc:opendocument:xmlns:container" \
            -t \
            -v '//c:rootfile[1]/@full-path' \
            "$WORK/META-INF/container.xml" 2>/dev/null
    )"

    if [[ -z "$OPF_REL" ]]; then
        echo "Error: could not locate OPF." >&2
        return 1
    fi

    OPF="$WORK/$OPF_REL"
    OPF_DIR="$(dirname "$OPF")"

    if [[ ! -f "$OPF" ]]; then
        echo "Error: OPF not found: $OPF" >&2
        return 1
    fi

    if ! xmlstarlet val --well-formed "$OPF" >/dev/null 2>&1; then
        echo "Invalid OPF detected. Attempting to repair known corruption..."

        perl -0pi -e '
            s{
                <item
                \s+id="ncx"
                \s+href="([^"]+)"
                \s+media-type="application/x-dtbncx\+xml"
                \s+id="stylesheet"
                \s+href="[^"]*"
                \s+media-type="text/css"
                \s*/>
            }{
                <item id="ncx" href="$1" media-type="application/x-dtbncx+xml"/>
            }gx
        ' "$OPF"

        perl -0pi -e 's/\s*<item\s*\/>\s*<\/manifest>/<\/manifest>/g' "$OPF"

        if ! xmlstarlet val --well-formed "$OPF" >/dev/null 2>&1; then
            echo "Error: could not repair OPF." >&2
            return 1
        fi

        echo "Known corruption repaired."
    fi

    echo "Reading language..."

    LANGUAGE="$(
        xmlstarlet sel \
            -N dc="http://purl.org/dc/elements/1.1/" \
            -t \
            -v 'string((//dc:language)[1])' \
            "$OPF" 2>/dev/null
    )"

    [[ -z "$LANGUAGE" ]] && LANGUAGE="en"

    IDENTIFIER="urn:uuid:$(cat /proc/sys/kernel/random/uuid)"
    MODIFIED="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    echo "Removing images..."

    find "$WORK" -type f \
        \( \
            -iname '*.jpg' \
            -o -iname '*.jpeg' \
            -o -iname '*.jpe' \
            -o -iname '*.png' \
            -o -iname '*.gif' \
            -o -iname '*.webp' \
            -o -iname '*.bmp' \
            -o -iname '*.tif' \
            -o -iname '*.tiff' \
            -o -iname '*.avif' \
            -o -iname '*.svg' \
            -o -iname '*.svgz' \
            -o -iname '*.ico' \
            -o -iname '*.jp2' \
            -o -iname '*.j2k' \
            -o -iname '*.jpf' \
            -o -iname '*.heic' \
            -o -iname '*.heif' \
        \) \
        -delete

    echo "Removing original stylesheets..."

    find "$WORK" -type f \
        \( -iname '*.css' -o -iname '*.scss' \) \
        -delete

    CSS_DIR="$OPF_DIR/styles"
    CSS_FILE="$CSS_DIR/stylesheet.css"

    mkdir -p "$CSS_DIR"
    cp "$STYLESHEET" "$CSS_FILE"

    CSS_HREF="$(
        python3 -c \
            'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' \
            "$CSS_FILE" "$OPF_DIR"
    )"

    CSS_HREF="${CSS_HREF//\\//}"

    echo "Cleaning XHTML..."

    while IFS= read -r -d '' XHTML; do

        perl -0pi -e '
            s/&nbsp;/&#160;/g;
            s/&copy;/&#169;/g;
            s/&reg;/&#174;/g;
            s/&trade;/&#8482;/g;
            s/&mdash;/&#8212;/g;
            s/&ndash;/&#8211;/g;
            s/&hellip;/&#8230;/g;
            s/&ldquo;/&#8220;/g;
            s/&rdquo;/&#8221;/g;
            s/&lsquo;/&#8216;/g;
            s/&rsquo;/&#8217;/g;
            s/&laquo;/&#171;/g;
            s/&raquo;/&#187;/g;
            s/&middot;/&#183;/g;
        ' "$XHTML"

        xmlstarlet ed -P -L \
            -d '//@class' \
            -d '//@style' \
            -d '//*[local-name()="img"]' \
            -d '//*[local-name()="svg"]' \
            -d '//*[local-name()="picture"]' \
            -d '//*[local-name()="object"]' \
            -d '//*[local-name()="embed"]' \
            -d '//*[local-name()="link" and contains(concat(" ", normalize-space(@rel), " "), " stylesheet ")]' \
            "$XHTML"

        XHTML_DIR="$(dirname "$XHTML")"

        XHTML_CSS_HREF="$(
            python3 -c \
                'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' \
                "$CSS_FILE" "$XHTML_DIR"
        )"

        XHTML_CSS_HREF="${XHTML_CSS_HREF//\\//}"

        if grep -qi '<head\b' "$XHTML"; then
            perl -0pi -e \
                's{(<head\b[^>]*>)}{$1<link rel="stylesheet" type="text/css" href="'"$XHTML_CSS_HREF"'" />}i' \
                "$XHTML"
        fi

    done < <(
        find "$WORK" -type f \
            \( \
                -iname '*.xhtml' \
                -o -iname '*.html' \
                -o -iname '*.htm' \
            \) \
            -print0
    )

    echo "Creating cover..."

    COVER_DIR="$OPF_DIR/images"
    COVER="$COVER_DIR/cover.jpg"

    mkdir -p "$COVER_DIR"

    if ! magick \
        -size 1200x1800 \
        xc:'#202020' \
        -gravity center \
        -fill '#F0F0F0' \
        -font Liberation-Serif \
        -pointsize 86 \
        -interline-spacing 18 \
        -annotate +0-80 "$TITLE" \
        -fill '#B8B8B8' \
        -pointsize 48 \
        -annotate +0+180 "$AUTHOR" \
        -quality 90 \
        "$COVER"; then
        echo "Error: could not create cover." >&2
        return 1
    fi

    COVER_HREF="$(
        python3 -c \
            'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' \
            "$COVER" "$OPF_DIR"
    )"

    COVER_HREF="${COVER_HREF//\\//}"

    echo "Normalizing OPF..."

    TMP_OPF="$TMP/content.opf"

    if ! xmlstarlet tr \
    "$XSLT" \
    -s "title=$TITLE" \
    -s "author=$AUTHOR" \
    -s "language=$LANGUAGE" \
    -s "identifier=$IDENTIFIER" \
    -s "modified=$MODIFIED" \
    -s "css-href=$CSS_HREF" \
    -s "cover-href=$COVER_HREF" \
    "$OPF" > "$TMP_OPF"; then
        echo "Error: failed to process OPF." >&2
        return 1
    fi

    if ! xmlstarlet val --well-formed "$TMP_OPF" >/dev/null 2>&1; then
        echo "Error: the new OPF is not valid XML." >&2
        return 1
    fi

    mv "$TMP_OPF" "$OPF"

    echo "Validating XHTML..."

    while IFS= read -r -d '' XHTML; do
        if ! xmlstarlet val --well-formed "$XHTML" >/dev/null 2>&1; then
            echo "Error: invalid XHTML: $XHTML" >&2
            return 1
        fi
    done < <(
        find "$WORK" -type f \
            \( \
                -iname '*.xhtml' \
                -o -iname '*.html' \
                -o -iname '*.htm' \
            \) \
            -print0
    )

    echo "Repackaging..."

    if ! (
        cd "$WORK" &&
        zip -q -X -0 "$OUTPUT" mimetype &&
        zip -q -X -r "$OUTPUT" . -x mimetype
    ); then
        echo "Error: could not create EPUB." >&2
        return 1
    fi

    echo "Validating EPUB..."

    if ! unzip -tq "$OUTPUT" >/dev/null; then
        echo "Error: the resulting EPUB is invalid." >&2
        return 1
    fi

    if ! mv "$OUTPUT" "$EPUB"; then
        echo "Error: could not replace original EPUB." >&2
        return 1
    fi

    cleanup

    echo "Completed: $EPUB"
}

while IFS= read -r -d '' EPUB; do
    if ! process_epub "$EPUB"; then
        cleanup
        echo "Failed: $EPUB"
        echo "The original file has been preserved."
    fi
done < <(
    find "$ROOT_DIR" \
        -type f \
        -iname '*.epub' \
        -print0
)

echo
echo "Processing complete."
