#dwreplace
Search and replace command line tool for large numbers of HTML files with only Perl as a dependency. Uses iterative approach to match against multiple text sections within multiple files. 

## Quick Start

Generate a sample "rfile":
`perl dwreplace.pl --e > /tmp/myreplacements.rfile`

Edit rfile, one block per replacement:
```
# example: replace the top nav with some PHP
$OLD[0] = <<'END_OF_TEXT';
{$topnav}
END_OF_TEXT
# replace with this block
$NEW[0] = <<'END_OF_TEXT';
<?php echo $TOPNAV; ?>
END_OF_TEXT
# replace closing head tag with include file
$OLD[1] = <<'END_OF_TEXT';
</head>
END_OF_TEXT
# replace with this block
$NEW[1] = <<'END_OF_TEXT';
<?php include("includefile.php"); ?>
</head>
END_OF_TEXT
```
Run dwreplace on content, (typically) combined with "find", using --s for "search only":

` find . -print0 | grep \.htm | perl  ~/dev/dwreplace/dwreplace.pl --null --s --rfile=myreplacements.rfile `

This will show you how many matches would have been made. Modify your rfile until "2 matches found" is printed for all files.

Remove --s to do final replacement.

` find . -print0 | grep \.htm | perl  ~/dev/dwreplace/dwreplace.pl --null --rfile=myreplacements.rfile `

This tool was featured in Sysadmin Mag (later Dr. Dobb's Journal) in 2006. [Dr. Dobb's article](http://www.drdobbs.com/better-find-and-replace-on-html-content/199102179)




