#!/usr/bin/env perl
#####
# opsymbols.pl
# Andy Hammerlindl 2010/06/01
#
# Extract mapping such as '+' --> SYM_PLUS from camp.l
#####

open(header, ">opsymbols.h") ||
    die("Couldn't open opsymbols.h for writing");

print header <<END;
/*****
 * This file is automatically generated by opsymbols.pl
 * Changes will be overwritten.
 *****/

// If the OPSYMBOL macro is not defined for a specific purpose, define it with
// the default purpose of using SYM_PLUS etc. as external pre-translated
// symbols.

#ifndef OPSYMBOL
#define OPSYMBOL(str, name) extern sym::symbol name
#endif

END

sub add {
    print header "OPSYMBOL(\"".$_[0]."\", " . $_[1] . ");\n";
}

open(lexer, "camp.l") ||
        die("Couldn't open camp.l");

while (<lexer>) {
    if (m/^"(\S+)"\s*{\s*DEFSYMBOL\((\w+)\);/) {
        add($1, $2);
    }
    if (m/^(\w+)\s*{\s*DEFSYMBOL\((\w+)\);/) {
        add($1, $2);
    }
}
