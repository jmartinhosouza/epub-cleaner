## EPUB Cleaner

This repository contains a Shell script to normalize and standardize EPUB files according to a custom stylesheet.

The goal is to transform EPUBs from different sources into visually more consistent files, removing elements that I consider superfluous and applying uniform typography.

### What does it do?

For each `.epub` file found in the current directory and its subdirectories, the script:

* removes all images to save storage;
* generates a simple cover from the title and author;
* removes existing metadata, preserving only the title, author, and language;
* removes the original stylesheets;
* removes presentation classes and styles from the XHTML documents;
* applies a custom stylesheet;
* preserves the EPUB structure and navigation;
* replaces the original file only after generating and validating the new version.

The result is a more predictable and consistent EPUB across different books and readers.

### Dependencies

The script requires:

* Bash
* `unzip`
* `zip`
* `xmlstarlet`
* `perl`
* ImageMagick