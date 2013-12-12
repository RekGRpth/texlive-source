#!/usr/bin/env texlua  

VERSION = "0.3.1"

--[[
     pmx2pdf: processes MusiXTeX files using pmxab as a pre-processor 
     (and deletes intermediate files)

     (c) Copyright 2011-13 Bob Tennent rdt@cs.queensu.ca

     This program is free software; you can redistribute it and/or modify it
     under the terms of the GNU General Public License as published by the
     Free Software Foundation; either version 2 of the License, or (at your
     option) any later version.

     This program is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
     Public License for more details.

     You should have received a copy of the GNU General Public License along
     with this program; if not, write to the Free Software Foundation, Inc.,
     51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

--]]

--[[

  ChangeLog:
     version 0.3.1 2013-12-11 RDT
       added -F fmt option

     version 0.3.0 2013-12-10 RDT
       added -c option to preprocess using pmxchords

     version 0.2.1 2012-05-15 RDT
       renamed to avoid possible name clashes

     version 0.2  2011-11-28 RDT
       added -i (retain intermediate files) option

     version 0.1  2011-07-12 RDT

--]]

function usage()
  print("Usage:  [texlua] pmx2pdf { option | basename[.pmx] } ... ")
  print("options: -v  version")
  print("         -h  help")
  print("         -l  latex (or pdflatex)")
  print("         -p  pdfetex (or pdflatex)")
  print("         -d  dvipdfm")
  print("         -s  stop at dvi")
  print("         -t  stop at tex/mid")
  print("         -i  retain intermediate files")
  print("         -c  preprocess using pmxchords")
  print("         -F fmt  use fmt as the TeX processor")
  print("         -f  restore default processing")
end

function whoami ()
  print("This is pmx2pdf version ".. VERSION .. ".")
end

whoami()
if #arg == 0 then
  usage()
  os.exit(0)
end

-- defaults:
tex = "etex"  
musixflx = "musixflx"
dvi = "dvips"
ps2pdf = "ps2pdf"
intermediate = 1

exit_code = 0
narg = 1
repeat
  this_arg = arg[narg]
  if this_arg == "-v" then
    os.exit(0)
  elseif this_arg == "-h" then
    usage()
    os.exit(0)
  elseif this_arg == "-l" then
    if tex == "pdfetex" then
      tex = "pdflatex"
    else
      tex = "latex"
    end
  elseif this_arg == "-p" then
    if tex == "latex" then
      tex = "pdflatex"
    else
      tex = "pdfetex"
    end
    dvi = ""; ps2pdf = ""
  elseif this_arg == "-d" then
    dvi = "dvipdfm"; ps2pdf = ""
  elseif this_arg == "-s" then
    dvi = ""; ps2pdf = ""
  elseif this_arg == "-f" then
    tex = "etex"; dvi = "dvips"; ps2pdf = "ps2pdf"; intermediate = 1
  elseif this_arg == "-t" then
    tex = ""; dvi = ""; ps2pdf = ""
  elseif this_arg == "-i" then
    intermediate = 0
  elseif this_arg == "-F" then
    narg = narg+1
    tex = arg[narg]
  else
    filename = this_arg 
    if filename ~= "" and string.sub(filename, -4, -1) == ".pmx" then
        filename = string.sub(filename, 1, -5)
    end
    if not io.open(filename .. ".pmx", "r") then
      print("Non-existent file: ", filename .. ".pmx")
    else
      print("Processing ".. filename .. ".pmx.")
      os.remove( filename .. ".mx2" )
      os.execute("pmxab" .. " " .. filename )
      pmxaerr = io.open("pmxaerr.dat", "r")
      if (not pmxaerr) then
        print("No log file.")
        os.exit(1)
      end
      linebuf = pmxaerr:read()
      err = tonumber(linebuf)
      pmxaerr:close()
      if ( err == 0 ) and
         (tex == "" or os.execute(tex .. " " .. filename) == 0) and
         (tex == "" or os.execute(musixflx .. " " .. filename) == 0) and
         (tex == "" or os.execute(tex .. " " .. filename) == 0) and
         ((tex ~= "latex" and tex ~= "pdflatex") 
           or (os.execute(tex .. " " .. filename) == 0)) and
         (dvi == "" or  (os.execute(dvi .. " " .. filename) == 0)) and
         (ps2pdf == "" or (os.execute(ps2pdf .. " " .. filename .. ".ps") == 0) )
      then 
        if ps2pdf ~= "" then
          print(filename .. ".pdf generated by " .. ps2pdf .. ".")
        end
        if intermediate == 1 then -- clean-up:
          os.remove( "pmxaerr.dat" )
          os.remove( filename .. ".mx1" )
          os.remove( filename .. ".mx2" )
          if dvi ~= "" then
            os.remove( filename .. ".dvi" )
          end
          if ps2pdf ~= "" then 
            os.remove( filename .. ".ps" )
          end
        end
      else
        print("PMX/MusiXTeX processing of " .. filename .. ".pmx fails.\n")
        exit_code = 2
        --[[ uncomment for debugging
        print("tex = ", tex)
        print("dvi = ", dvi)
        print("ps2pdf = ", ps2pdf)
        --]]
      end

    end --if not io.open ...
  end --if this_arg == ...
  narg = narg+1
until narg > #arg 
os.exit( exit_code )
