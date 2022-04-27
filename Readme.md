# Notion Postprocess

*Notion Postprocess* is a utility to aid in the migration of content from Notion to Craft. It works on input from the Markdown export provided by the Notion app (called “Markdown & CSV”) and processes a hierarchy of specific pages and subpages  or a whole workspace export in one step. The resulting structure of directories and files can be imported into Craft as-is, with working resource paths (images, videos, other media) and page links.

# Installation

Notion Postprocess is currently available for *macOS* only. It can be built from source by cloning the project and building or archiving using Apple Xcode with the included project file.

Prebuilt binaries are also available at [https://gitlab.com/apricum/notion-postprocess/-/releases](https://gitlab.com/apricum/notion-postprocess/-/releases). Download the binary package for the most recent version, run the utility from there, or install into your `$PATH`, e.g. into `/usr/local/bin/notion-postproces`.

Sitenote: With a manifest file (`Package.swift`) for the Swift Package Manager, the project may be built for *Linux* and *Windows*, likely without needing other changes. The current releases are only built with Xcode for saving time in development.

# Usage

The postprocess utility offers two independent passes, one for *rewrite*, one for *regroup*. All changes are made in-place, changing the given input directories and files on the file system. The pass to run can be specified as an optional first argument; when omitted, both passes are run sequentially.

Note that the *regroup* operation is intended to use the output of the rewrite pass for best results, though it can theoretically be used with any input structure.

```other
USAGE: notion-postprocessor <mode> <input-path> [--dry-run]

ARGUMENTS:
  <mode>                  The mode of operation. (options: all|rewrite|regroup)
  <input-path>            Path to the directory exported from Notion to be processed.

OPTIONS:
  --dry-run               Print the changes made to the input but do not not execute them.
  --version               Show the version.
  -?, --help              Show help information.
```

# Examples

```Bash
# Rewrite and regroup all files and directories
notion-postprocessor all "./Workspace Export" --dry-run
```

```Bash
# Rewrite all files and directories
notion-postprocessor rewrite "./Workspace Export"
```

```Bash
# Regroup files with associated group directories
notion-postprocessor regroup "./Workspace Export"
```

# In-Depth

This section documents what kind of changes are made by the utility.

## Rewrite

The *rewrite* pass recursively iterates over all directories and files, breadth-first, and performs the following operations:

### Name Restoration

Restore the intended name of all documents. When Notion exports files, their names are truncated and get an identifier appended that has no purpose outside of Notion (e.g. `New Digital` becomes `New Digita 78d87`). This step restores the original intended name by reading the first-level heading of the document. The name mapping is also cached if it reappears in other parts of the hierarchy.

### Document Headings

Remove first-level headings in all documents. Craft takes document titles from their file name when importing data. Leaving the first-level heading in the document would appear as a duplicate.

### Callout Blocks

Unwrap content from Notion “callout” blocks. Craft does not expose its own “block highlight” through Markdown (only its quote style). Changing the former callout block content manually is easier if migrated clean (as content only). The currently edited block can be made a block highlight with ⌘⇧'.

### Code Blocks

Convert language identifiers in code blocks. Some language identifiers in Markdown content blocks use different identifiers in Craft, these are converted to their new versions (for example `js` becomes `JavaScript`).

### Embedded Content Links

Rewrite embedded content links (files like images and videos). Changing file and directory names requires the link paths inside of documents to be changed as well. The utility creates a map (or “index”) of name changes that is also used to rewrite links. For instance, a document embedding an image will have a new valid link to that image after the rewrite. External links are not affected by the rewrite.

### Document Links

Rewrite cross-document links. Like embedded media files, links between documents are changed as well to match their path after the rewrite is performed — all links between documents should work after being imported into Craft.

## Regroup

Regrouping is is an *optional* refinement step. This step restructures documents to move them inside their corresponding folder if one exists. By default, the structure exported by Notion leaves parent and child pages in a form like the following:

```other
<Notion Export>
├── Projects
│   ├── Autumn 1988 Project
│   │   └── <more files>
│   ├── Spring 1989 Project
│   │   └── <more files>
│   ├── Autumn 1988 Project.md
│   └── Spring 1989 Project.md
└── Projects.md
```

After the regrouping operation, files belonging to a specific group have been moved inside the associated directory. The same structure then looks like this:

```other
<Notion Export>
└── Projects
    ├── Autumn 1988 Project
    │   ├── Autumn 1988 Project.md
    │   └── <more files>
    ├── Spring 1989 Project
    │   ├── Spring 1989 Project.md
    │   └── <more files>
    └── Projects.md
```

The resulting structure has much better readability and ergonomics when imported into Craft where nested documents work differently.

The *regroup* pass performs the following operations:

### Move Documents

Find documents and directories with the same name to match up. Move documents inside their associated folder if one is found.

### Document Links

Rewrite resource and document links. This step finds paths where the processed document name appears as part of a path and rewrites it. Makes resource links match the structure changed by the regrouping pass.

