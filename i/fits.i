/*
 * fits.i -
 *
 *	Implement FITS files input/output and editing in Yorick.
 *
 * Copyright (c) 2000-2002 Eric THIEBAUT.
 *
 * History:
 *	$Id: fits.i,v 1.1 2005-09-18 22:06:00 dhmunro Exp $
 *	$Log: fits.i,v $
 *	Revision 1.1  2005-09-18 22:06:00  dhmunro
 *	Initial revision
 *
 *	Revision 1.16  2004/09/03 09:13:27  eric
 *	 - New function fits_pad_hdu to round up file size to a multiple
 *	   of FITS blocking factor.
 *	 - fits_new_hdu: fix offset of data part by calling fits_pad_hdu
 *	   (thanks to Antoine Merand for pointing this bug).
 *	 - fits_close: call fits_pad_hdu to finalize stream open for
 *	   writing.
 *	 - fits_new_image: bitpix and dimension list can be guessed from
 *	   suplementary argument.
 *
 *	Revision 1.15  2004/09/02 12:51:59  eric
 *	 **************** POTENTIAL INCOMPATIBILITY ******************
 *	 ***                                                       ***
 *	 ***  fits_read_bintable and fits_write_bintable modified  ***
 *	 ***  so that field dimensions are more consistent with    ***
 *	 ***  usual definition: the 'rows' of the table now run    ***
 *	 ***  along the first dimension of the fields and fields   ***
 *	 ***  with a repeat count of 1 can be simple vectors.      ***
 *	 ***                                                       ***
 *	 *************************************************************
 *
 *	 - fits_read_bintable: keyword SELECT has a different meaning
 *	 - fits_read_bintable: new keyword TRIM
 *	 - new function fits_pack_bintable, old version fits_pack_table
 *	   removed (it was broken and of little interest)
 *
 *	Revision 1.14  2004/07/09 18:05:34  eric
 *	 - Fix setting of BSCALE/BZERO in fits_create.
 *
 *	Revision 1.13  2004/07/09 12:45:58  eric
 *	 - New function fits_best_scale to compute optimal BSCALE and BZERO
 *	   for real to integer conversion.
 *	 - Function fits_write modified to use fits_best_scale by default.
 *	 - New keyword NATIVE for fits_bitpix_type function.
 *
 *	Revision 1.12  2004/07/09 09:30:37  eric
 *	 - Fixed bug in fits_move and typo in error message for fits_create
 *	   (thanks to Clementine Bechet).
 *
 *	Revision 1.11  2004/06/22 16:22:49  eric
 *	 - Fix a bug in fits_write_bintable which prevents writing strings in
 *	   a binary table (thanks to Clementine Bechet).
 *
 *	Revision 1.10  2004/03/19 18:28:45  eric
 *	 - New functions: fits_current_hdu, fits_info, fits_eof, fits_list.
 *	 - Fix bug in fits_goto_hdu when arriving at the end of the file
 *	   (thanks to Bastien Aracil).
 *
 *	Revision 1.9  2003/12/04 15:57:23  eric
 *	 - Fixed a bug in column order for BINTABLE.
 *
 *	Revision 1.8  2003/11/16 13:57:02  eric
 *	 - fits_read_bintable: new keywords RAW_STRING and RAW_LOGICAL;
 *	 - fits_set: fix for commentary card;
 *	 - fits_read_bintable_as_hashtable: new function to read a BINTABLE
 *	   and return it as a hash table (requires Yeti extension);
 *
 *	Revision 1.7  2003/05/23 14:12:43  eric
 *	 - New function fits_pack_table, resulting in new keywords PACK
 *	   and SELECT in fits_read and fits_read_bintable.
 *
 *	Revision 1.6  2003/03/28 14:48:54  eric
 *	 *** POSSIBLE INCOMPATIBILITY ***
 *	 Fields of a BINTABLE are now NCOLS(i)xNROWS arrays
 *	 (instead of NROWS or NROWSxNCOLS(i) arrays).
 *
 *	Revision 1.5  2003/03/28 14:01:17  eric
 *	 - fits_new_bintable: add optional comment.
 *
 *	Revision 1.4  2003/03/25 13:10:55  eric
 *	 - Keyword LOGICAL removed in fits_read.
 *
 *	Revision 1.3  2003/03/17 16:51:54  eric
 *	 - New keywords in fits_write, fits_create: template, history
 *	   and comment.
 *
 *	Revision 1.2  2003/01/31 15:10:07  eric
 *	 - Added support for obsolete FITS API.
 *
 *	Revision 1.1  2003/01/07 17:10:59  eric
 *	Initial revision
 *
 */

/*---------------------------------------------------------------------------*/
local fits;
fits = "$Revision: 1.1 $";
/* DOCUMENT fits - an introduction to Yorick interface to FITS files.

     The  routines  provided by  this  (standalone)  package  are aimed  at
     reading/writing  FITS (Flexible Image Transport  System) files from/to
     Yorick.  These  routines attempt to follow the  FITS standard (version
     1.1)  as defined in  NOST report  [1].  Nevertheless  the user  may be
     aware of some  limitations (some of which are  unavoidable with such a
     "flexible" format as FITS):

      - It  is still possible to  produce a non-standard  FITS file because
        (for obvious  efficiency reasons)  routines in this  package cannot
        check  everything.  At  least, FITS  routines check  that compliant
        FITS keywords  are used and that  mandatory cards (SIMPLE/XTENSION,
        BITPIX,  NAXIS, ...)   get written  in the  correct order  and with
        correct value types (see  fits_set).  Nevertheless, the user has to
        know only  very little  about FITS standard  to be able  to produce
        valid FITS files.

      - In this version  of the package, headers of  any FITS extension can
        be read/produced but  you can only read/write Yorick  array data or
        binary tables, i.e.  corresponding to primary data and FITS "IMAGE"
        or  "BINTABLE" extensions  (see  fits_read_array, fits_write_array,
        fits_read_bintable, and fits_write_bintable).  Support for standard
        extensions (such  as ASCII  table "TABLE") is  planned but  not yet
        done.

      - There  is   no  special   handling  of  IEEE  special  values  NaN,
        +/-Infinity (using such values is  likely to raise a floating point
        error catched by Yorick).

      - You  cannot read/write  compressed  FITS  files.   You'll  have  to
        pre-decompress or post-compress files  (you can use Yorick "system"
        function to that end).

      - It is (not yet) possible to re-open an existing FITS file to modify
        it.  But it would be very easy to allow for appending extensions to
        an existing file (should be provided very soon).

     Some simple driver routines  are provided to allow for reading/writing
     Yorick arrays from/to FITS file  and may be sufficient for basic usage
     (see fits_read and fits_write).


   READING AN EXISTING FITS FILE

     There is a simplified driver fits_read  (which see) to read data in an
     existing FITS file.  The following example demontrates how to read the
     contents of a FITS file with the basic routines:

     fh = fits_open(name);                 // open existing file and read
                                           // header of 1st (primary) HDU
     data1 = fits_read_array(fh);          // read all "image" data in 1st HDU
     slice = fits_read_array(fh, which=n); // read N-th data slice in current
                                           // HDU
     fits_next_hdu, fh;                    // move to next HDU and read header
     data2 = fits_read_array(fh);          // read data of secondary HDU
     ...;


   CREATING A NEW FITS FILE:

     There is a (very) simplified driver fits_write (which see) to create a
     new  FITS  file to  store  a  Yorick  array.  The  following  examples
     demontrate  how to write a moderately complex FITS file with the basic
     routines (assuming DATA1 is a 2-dimensional array):

       fh = fits_open(name, 'w');      // create new file
       fits_set, fh, "SIMPLE", 'T',    "true FITS file";
       fits_set, fh, "BITPIX", bitpix, "bits per pixel";
       fits_set, fh, "NAXIS",  naxis,  "number of dimensions";
       fits_set, fh, "NAXIS1", dim1,   "length of 1st dimension";
       fits_set, fh, "NAXIS2", dim2,   "length of 2nd dimension";
       fits_set, fh, "EXTEND", 'T', "this file may contain FITS extensions";
       fits_set, fh, ...               // set any number of other cards with
       ...                             // several calls to fits_set
       fits_write_header, fh;          // write header part of current HDU
       fits_write_array, fh, data1;    // write data part of current HDU

       fits_new_hdu, fh, "IMAGE";        // append new "IMAGE" extension
       fits_set, fh, "BITPIX", bitpix, "bits per pixel";
       fits_set_dims, fh, dimsof(data2); // set all dimensions in one call
       fits_set, fh, ...                 // set any number of other cards with
       ...
       fits_write_header, fh;            // write header part of extension
       fits_write_array, fh, data2;      // write data part of extension
       fits_close, fh;                   // close stream of FITS handle, the
                                         // header can still be examined

     Note  that the cards  with the  dimensions of  the data  array (NAXIS,
     NAXIS1, ...)  which  are explicitly set with fits_set  for the primary
     header can  also be instanciated  in a more  simple way thanks  to the
     function fits_set_dims as shown for the second HDU.

     Alternatively, The function fits_create can be used to open a new file
     and setup  a basic primary header.   In this case, the  first lines of
     the above examples become:
     
       fh = fits_create(name, 'w', extend=1,
                        bitpix=fits_bitipix_of(data1),
                        dimslist=dimsof(data1));
       fits_set, fh, ...               // set any number of other cards with
       ...                             // several calls to fits_set
       fits_write_header, fh;          // write header part of current HDU
       fits_write_array, fh, data1;    // write data part of current HDU

     If you intend to write more than one HDU, do not forget to set card
     EXTEND to true in the primary header (this is done in the two examples
     above with fits_open and with fits_create).


   LIST OF ROUTINES

     By convention, in this Yorick package, all public symbols (routines or
     variables)  are prefixed  with  "fits_" and  all  private symbols  are
     prefixed with "_fits_".  The following (public) routines are provided:

     File routines:
       fits_check_file     - check whether a file may be a FITS file
       fits_open           - open existing FITS file or create new FITS file
       fits_close          - close file stream in FITS handle
       fits_create         - creates a new FITS file with minimal header
       fits_filename       - get full path name of FITS stream

     Header/HDU routines:
       fits_current_hdu    - returns number of current HDU
       fits_goto_hdu       - go to a given HDU number
       fits_list           - get list of extensions in a FITS file
       fits_next_hdu       - move to next HDU and parse the header part
       fits_pad_hdu        - pad current HDU to a multiple of 2880 bytes
       fits_rewind         - goto first (primary) HDU
       fits_new_hdu        - start a new FITS extension
       fits_read_header    - read header part of current HDU
       fits_write_header   - write header part of current HDU

     Card routines:
       fits_delete         - delete card(s) from header of current HDU
       fits_get            - get value of FITS card(s) in current HDU
       fits_get_bitpix     - get BITPIX value
       fits_get_bscale     - get BSCALE value
       fits_get_bzero      - get BZERO value
       fits_get_cards      - get all cards matching a pattern
       fits_get_comment    - get value(s) of COMMENT card(s)
       fits_get_coordinate - get coordinate information for a given axis
       fits_get_data_size  - get size of data part in current HDU.
       fits_get_dims       - get dimension list of array data
       fits_get_gcount     - get GCOUNT value
       fits_get_history    - get value(s) of HISTORY card(s)
       fits_get_keywords   - get list of defined keywords
       fits_get_naxis      - get NAXIS value
       fits_get_pcount     - get PCOUNT value
       fits_get_xtension   - get name of FITS primary/extension HDU
       fits_move_card      - move FITS card
       fits_parse          - parse FITS card(s)
       fits_set            - set value of FITS card(s) in current HDU
       fits_set_dims       - set FITS card(s) for dimension list of array

     Reading/writing data (also see binary table routines):
       fits_read           - simple driver to read "IMAGE" or "BINTABLE" data
       fits_write          - simple driver to write "IMAGE" data
       fits_new_image      - creates a new "IMAGE" HDU
       fits_read_array     - read array data from current HDU
       fits_write_array    - write array data in current HDU

     Binary tables:
       fits_new_bintable   - creates a new "BINTABLE" HDU
       fits_read_bintable  - read binary table from current HDU
       fits_write_bintable - write binary table in current HDU
       fits_pack_bintable  - make table columns into a single array

     Expert users routines:
       fits_get_special    - get FITS value of mandatory FITS key
       fits_init           - (re)initialize FITS internals
       fits_id             - get numerical identifier of a single card
       fits_ids            - get numerical identifier of FITS card(s)
       fits_key            - converts numerical identifier into string
       fits_match          - find FITS card(s) which match a pattern
       fits_rehash         - recalculate the numerical identifiers of cards

     Miscellaneous routines:
       fits_best_scale     - compute best BSCALE and BZERO parameters
       fits_bitpix_info    - get description of FITS bits-per-pixel value
       fits_bitpix_of      - compute FITS bits-per-pixel value
       fits_bitpix_type    - convert FITS bits-per-pixel value to data type
       fits_check_bitpix   - test if FITS bits-per-pixel value is valid
       fits_date           - get current time as standard FITS date string
       fits_is_integer     - checks whether argument is integer
       fits_is_integer_scalar - checks whether argument is integer scalar
       fits_is_real_scalar - checks whether argument is real scalar
       fits_is_scalar      - checks whether argument is scalar or not
       fits_is_string_scalar - checks whether argument is scalar string or not
       fits_map            - map scalar function onto array argument
       fits_move           - move element of an array in-place
       fits_nth            - format a string in the form: "1st", "2nd", ...
       fits_tolower        - convert string(s) to lower case letters
       fits_toupper        - convert string(s) to upper case letters
       fits_trim           - removes trailing spaces


   CHANGES WITH RESPECT TO "OLD" FITS PACKAGES

     This  package is  intended to  be used  in place  of the  old "fits.i"
     (written by me  and distributed along with Yorick)  which had too many
     limitations and restrictions to allow for further extensions.  However
     the API provided by this novel package is quite different from the old
     one (in particular  the FITS header is no longer  stored into a Yorick
     structure but in some "opaque"  object: a FITS handle).  Hopefully the
     new package provides all the  routines needed to deal with this opaque
     handle but  the name of the  routines (all prefixed  with "fits_") and
     their calling sequences have changed.

     The new FITS interface was written with the aim of being:
       (1) conformable with FITS standards (although try to be not too strict
           when _reading_ files)
       (2) flexible and extensible
       (3) fast (e.g. fits_get takes ~ 150 microseconds for a FITS header
           with 200 cards on an PIII @ 1GHz)


   FITS HANDLE

     In this package, a FITS handle  (denoted FH in the documentation) to a
     FITS file  is intended to  be an "opaque"  object.  Actually, it  is a
     list of 4 items organized as follow:
        _lst(cards, ids, descr, stream)
        cards  = vector of strings which are the header cards of the
                 current HDU;
        ids    = vector of card identifier values (this is for fast search
                 of cards);
        descr  = descriptor, vector of long integers:
                   DESCR(1)= current HDU number (1 for primary HDU);
                   DESCR(2)= file address of the current HDU
                   DESCR(3)= file address of the data part for the current HDU
                   DESCR(4)= file address of the next HDU in read mode,
                             number of written bytes in write mode
                   DESCR(5)= file mode: 'r' (read) or 'w' (write)
        stream = void (no associated file) or stream for input or output;

     Of course the  end-user should never directly access  the items of the
     FITS handle  but rather  use the provided  FITS routines (so  that, in
     order  to  warant portability  of  the user  level  code,  it will  be
     sufficient  to  only modify  routines  in  this  package whenever  the
     internals of the FITS handle change).


   WISH LIST

     The following is a list of missing features or things I would like to
     test:

       1. Implement  support  for  "random groups"  records  (FITS keywords
          GROUPS, PCOUNT  and GCOUNT) and other  "standard" FITS extensions
          (only "IMAGE" and "BINTABLE" are implemented): ASCII table, ...
       2. Extensively test the package (this is mainly because I lack
          of sample FITS files written by other software).
       3. Deal with compressed FITS files; this will be possible thanks to
          the "channel" interface in Yeti (my own extension of Yorick).
       4. Enhance  the consistency  checks  (for instance,  in the  current
          version, you can read/write an "image" into a "table" extension).


   GLOSSARY

     HDU - Header and Data Unit
     Indexed Keyword -


   REFERENCES

     [1] "Definition of Flexible Image Transport System (FITS)", NASA/Science
         Office of Standards and Technology, report NOST 100-1.1, September 29,
         1995.

     [2] "A User's Guide for the Flexible Image Transport System (FITS)"
         http://archive.stsci.edu/fits/users_guide/

*/

/* TO DO LIST:
    - support for strings in fits_write_bintable
    - complex integer
    - ASCII tables
    - free format for real numbers
    - in fits_init: _fits_digitize -> double ?
*/

/*---------------------------------------------------------------------------*/
/* INFORMATION */

func fits_info(fh, hdu)
/* DOCUMENT fits_info, fh;
       -or- fits_info, fh, hdu
       -or- fits_info, filename;
       -or- fits_info, filename, hdu;
     Prints header contents of current HDU in FITS handle FH or all HDU's
     in FITS file FILENAME.  If argument HDU is given, only this header unit
     get printed out (HDU may be an array).
     
   SEE ALSO: fits, fits_open. */
{
  local cards, offset;
  if (structof(fh) == string) {
    fh = fits_open(fh);
    if (is_void(hdu)) {
      while (_fits_info_worker(fh)) {
        fits_next_hdu, fh;
      }
    } else {
      for (i=1 ; i<=numberof(hdu) ; ++i) {
        _fits_info_worker, fits_goto_hdu(fh, hdu(i));
      }
    }
  } else {
    if (is_void(hdu)) {
      _fits_info_worker, fh;
    } else {
      for (i=1 ; i<=numberof(hdu) ; ++i) {
        _fits_info_worker, fits_goto_hdu(fh, hdu(i));
      }
    }
  }
}

func _fits_info_worker(fh)
{
  local cards; eq_nocopy, cards, _car(fh,1);
  ncards = numberof(cards);
  if (ncards) {
    local offset; eq_nocopy, offset, _car(fh,3);
    write, format="********  HDU - %3d  ***********************************************************\n", offset(1);
    for (i=1; i<=ncards ; ++i) write, format="%s\n", cards(i);
  } else {
    write, format="******** %s ***********************************************************\n", "END OF FILE";
  }
  return ncards;
}


/*---------------------------------------------------------------------------*/
/* SIMPLIFIED DRIVERS */

func fits_read(filename, &fh, encoding=, hdu=, which=, rescale=,
               pack=, select=)
/* DOCUMENT fits_read(filename)
       -or- local fh; a = fits_read(filename, fh)
     Open  FITS file  FILENAME and  read data.   FH is  an  optional output
     symbol where  the FITS handle  will be stored  for future use  such as
     moving  to  a  FITS  extension  in  the  same  file  and  reading  its
     header/data.  (Note:  a FITS handle is  a Yorick list  that contains a
     file handle and all header information from the current HDU.)

     By  default, the data  get read  from the  first HDU  but this  can be
     changed with the HDU keyword (default HDU=1, i.e. primary HDU).

     Keyword ENCODING has the same meaning as in fits_open (which see).

     Keywords WHICH and RESCALE have the same meaning as in fits_read_array
     (which see).  These keywords are ignored if HDU to read is not primary
     HDU nor an "image" extension.

     Keywords   PACK   and   SELECT   have   the   same   meaning   as   in
     fits_read_bintable (which see).

   SEE ALSO: fits, fits_write, fits_open,
             fits_read_array, fits_read_bintable. */
{
  fh = fits_open(filename, 'r', encoding=encoding);
  if (is_void(hdu)) hdu = 1;
  else if (hdu != 1) fits_goto_hdu, fh, hdu;
  if (hdu == 1 || (xtension = fits_get(fh, "XTENSION")) == "IMAGE")
    return fits_read_array(fh, which=which, rescale=rescale);
  if (xtension == "BINTABLE")
    return fits_read_bintable(fh, pack=pack, select=select);
  if (structof(xtension) == string)
    error, "FITS extension \""+xtension+"\" not supported";
  error, "invalid FITS file (missing/bad XTENSION card)";
}

func fits_write(filename, data, encoding=, overwrite=,
                bitpix=, extend=, bscale=, bzero=,
                template=, history=, comment=)
/* DOCUMENT fits_write, filename, data;
       -or- fits_write(filename, data)
     Creates a new FITS file FILENAME  and write array DATA in primary HDU.
     When called  as a function,  the result is  a FITS handle that  can be
     used to append extensions to the file.

     FITS "bits-per-pixel"  can be specified by  keyword BITPIX; otherwise,
     BITPIX   is   automatically   guessed   from  the   data   type   (see
     fits_bitpix_of).

     Keywords  EXTEND, TEMPLATE, HISTORY  COMMENT, BSCALE,  BZERO, ENCODING
     and OVERWRITE have the same meaning as in fits_create (to see).

     If BITPIX is explicitely specified  and corresponds to an integer file
     type (8, 16 or 32) and neither BSCALE nor BZERO are specified, optimal
     BSCALE  and BZERO  values  will be  automatically  computed thanks  to
     fits_best_scale (which see).

   SEE ALSO: fits, fits_best_scale, fits_bitpix_of, fits_create,
             fits_write_header, fits_write_array. */
{
  if (! is_array(data)) error, "non-array data";
  if (is_void(bitpix)) {
    bitpix = fits_bitpix_of(data);
  } else if (bitpix > 0 /* integer file type */
             && is_void(bscale) && is_void(bzero)) {
    scale = fits_best_scale(bitpix, data);
    bscale = scale(1);
    bzero = scale(2);
  }
  fh = fits_create(filename, encoding=encoding, overwrite=overwrite,
                   bitpix=bitpix, bzero=bzero, bscale=bscale,
                   dimlist=dimsof(data), extend=extend,
                   template=template, history=history, comment=comment);
  fits_write_header, fh;
  fits_write_array, fh, data;
  return fh;
}

func fits_best_scale(bitpix, cmin, cmax, debug=)
/* DOCUMENT fits_best_scale(bitpix, data)
       -or- fits_best_scale(bitpix, cmin, cmax)
     Returns [BSCALE,BZERO]  where BSCALE and BZERO are  optimal values for
     rescaling to BITPIX  file type.  BITPIX must correspond  to an integer
     type (BITPIX = 8, 16 or 32).  The array DATA contains all the physical
     values  to save to  the file;  alternatively, CMIN  and CMAX  give the
     minimal and maximal values in physical data.

   SEE ALSO: fits, fits_write. */
{
  if (bitpix == 8) {
    fmin = 0;
    fmax = 255;
  } else if (bitpix == 16) {
    fmin = -32768;
    fmax =  32767;
  } else if (bitpix == 32) {
    fmin = -2147483648;
    fmax =  2147483647;
  } else {
    error, "expecting BITPIX for integer file type";
  }
  if (is_void(cmax)) {
    /* CMIN is in fact the data array */
    cmax = max(cmin);
    cmin = min(cmin);
  }
  if (cmin == cmax) {
    return [1.0, cmin];
  }
  bscale = (double(cmax) - double(cmin))/(double(fmax) - double(fmin));
  bzero = floor(((cmin/bscale - fmin) + (cmax/bscale - fmax) + 1.)/2.)*bscale;
  if (debug) {
    if (bzero != (floor(cmin/bscale + 0.5) - fmin)*bscale ||
        bzero != (floor(cmax/bscale + 0.5) - fmax)*bscale) {
      _fits_warn, "rounding error in optimal BSCALE/BZERO";
    }
  }
  return [bscale, bzero];
}

/*---------------------------------------------------------------------------*/

func fits_open(filename, filemode, encoding=, overwrite=)
/* DOCUMENT fits_open(filename)
       -or- fits_open(filename, filemode)
     Opens  the FITS  file FILENAME  according to  FILEMODE.   The returned
     value is a FITS handle used  in most other FITS routines.  FILEMODE is
     one of:
       "r" or 'r' - read mode,  the header of the primary  HDU get read and
                    is parsed.
       "w" or 'w' - write   mode,  new  file  is  created  (unless  keyword
                    OVERWRITE is true, FILENAME must not already exists).
       "a" or 'a' - append  mode, stream  get positionned  at last HDU, the
                    header of the last HDU get read and parsed.
     The default FILEMODE is "r" -- open an existing FITS file for reading.

     Keyword ENCODING can  be used to change the data  encoding of the FITS
     file which is  "xdr" for a regular FITS file  (XDR means eXternal Data
     Representation,  which is  natively  used by  all  IEEE compliant  big
     endian machine).  The value of the keyword is a string like:
       "xdr", "sun"    - eXternal Data Representation (the default)
       "native"        - native data representation (i.e. no conversion)
       "i86", "pc"     - IEEE little endian machines
       ...
     see documentation for "__sun" for  a list of supported encodings. Note
     that  using  an encoding  different  from  IEEE  big endian  (or  XDR)
     violates FITS standard.

     Keyword OVERWRITE can be used to force overwriting of an existing file
     (otherwise it is an error to create a file that already exists).


   SEE ALSO: fits, fits_read_header, fits_write_header,
             fits_get, fits_set, fits_read_array, fits_write_array,
             fits_next_hdu, fits_new_hdu, fits_rewind, __sun. */
{
  /* Open stream. */
  if (is_void(filemode) || filemode == 'r' || filemode == "r") {
    filemode = 'r';
    stream = open(filename, "rb");
  } else if (filemode == 'w' || filemode == "w") {
    filemode = 'w';
    if (! overwrite && open(filename, "r", 1))
      error, "file \""+filename+"\" already exists";
    logfile = filename + "L";
    if (open(logfile, "r", 1)) logfile = string(0);
    stream = open(filename, "wb");
    if (logfile) remove, logfile;
  } else if (filemode == 'a' || filemode == "a") {
    filemode = 'a';
    error, "sorry \"append\" mode not yet implemented";
    stream = open(filename, "ab");
  }

  /* Set data primitives. */
  if (is_void(encoding)) encoding= "xdr";
  if (encoding != "native") {
    set_encoding = symbol_def(encoding+"_primitives");
    if (is_func(set_encoding) != 1) error, "bad encoding \""+encoding+"\"";
    set_encoding, stream;
  }
  save, stream, complex; /* make stream aware of the definition of a complex */

  /* Create handle. */
  fh = _lst([], [], [1, 0, 0, 0, filemode], stream);
  return (filemode == 'r' ? fits_read_header(fh) : fh);
}

func fits_close(fh)
/* DOCUMENT fits_close(fh)
     Closes stream in FITS handle  FH.  The header information stored in FH
     remain unchanged  (e.g. you can keep  editing the header  in FH).  The
     returned  value is FH.   Note that  if you  destroy all  references to
     handle FH, the  associated file (if any) gets  automatically closed by
     Yorick.

   SEE ALSO: fits, fits_pad_hdu, fits_open, close. */
{
  local offset; eq_nocopy, offset, _car(fh,3);
  local stream; eq_nocopy, stream, _car(fh,4);
  if (offset(5) == 'w') {
    /* Pad file up to a multiple of 2880 bytes. */
    fits_pad_hdu, fh;
  }
  offset(*) = 0;
  if (is_stream(stream)) {
    _car, fh, 4, [];
    close, stream;
  }
  return fh;
}

func fits_create(filename, encoding=, overwrite=, bitpix=, dimlist=, extend=,
                 template=, history=, comment=, bzero=, bscale=)
/* DOCUMENT fits_create(filename)   
     Creates  a new  FITS  file FILENAME  and  returns a  FITS handle  with
     mandatory cards (i.e. SIMPLE, BITPIX, NAXIS, NAXISn) and some optional
     cards (i.e. EXTEND, BSCALE and BZERO) already initialized.

     Keyword  BITPIX can  be  used to  set  FITS "bits-per-pixel"  (default
     is BITPIX=8, i.e. byte data).

     Keyword DIMLIST  should be used to  specify the dimension  list of the
     array data that  is intended to be written in  primary HDU.  The value
     of DIMLIST is similar to the result returned by dimsof.

     Keyword EXTEND can  be used to indicate whether  the file may contains
     FITS extensions.  It is probably a good idea to always use EXTEND=1.

     Keyword TEMPLATE can be set with  an existing FITS handle to copy some
     FITS cards  of the template into  the new header.  The  FITS card that
     are  _never_  copied  are:  "SIMPLE", "XTENSION",  "BITPIX",  "NAXIS",
     "NAXIS#" (with  # an integer),  "BSCALE" and "BZERO"; the  other cards
     get copied.  See keywords BSCALE and BZERO if you specifically want to
     set these values.
     
     Keywords BSCALE and BZERO can  be used to specify physical value scale
     and offset.   See fits_write_array to figure out  how keywords BITPIX,
     BSCALE and BZERO are used to convert data values into file values.

     Keywords HISTORY  and COMMENT can be  set to add some  comments in the
     new handle.  The values of these keywords may be array of strings.

     Keywords ENCODING and OVERWRITE have the same meaning as in fits_open
     routine (to see).


   SEE ALSO: fits, fits_open, fits_set, fits_set_dims. */
{
  /* Checking. */
  if (am_subroutine()) error, "fits_create must be called as a function";
  if (is_void(bitpix)) {
    bitpix = 8;
  } else if (! fits_is_integer_scalar(bitpix) || ! fits_check_bitpix(bitpix)) {
    error, "bad value for keyword BITPIX";
  }
  if (! is_void(extend)) {
    if (! fits_is_scalar(extend) || ((s = structof(extend)) != long &&
                                     s != int && s != short && s != char))
      error, "keyword EXTEND must be a scalar integer";
    if (s != char) extend = (extend ? 'T' : 'F');
    else if (extend!='T' && extend!='F') error, "bad value for keyword EXTEND";
  }

  /* Some constants. */
  scale_comment = "data_value = BZERO + BSCALE*file_value";
  
  /* Create new file and set minimal header. */
  fh = fits_open(filename, 'w', encoding=encoding, overwrite=overwrite);
  fits_set, fh, "SIMPLE", 'T',   "true FITS file created by Yorick";
  fits_set, fh, "BITPIX", bitpix, fits_bitpix_info(bitpix);
  fits_set_dims, fh, dimlist;
  if (! is_void(extend)) fits_set, fh, "EXTEND", extend,
                           ("this file "
                            + (extend == 'T' ? "may contain" : "contains no")
                            + " FITS extensions");
  if (! is_void(template)) {
    /* remove cards that we sureley don't want to keep */
    local ids; eq_nocopy, ids, _car(template, 2);
    keep = array(1n, numberof(ids));
    if (is_array((i = where(ids == _fits_id_simple  )))) keep(i) = 0n;
    if (is_array((i = where(ids == _fits_id_xtension)))) keep(i) = 0n;
    if (is_array((i = where(ids == _fits_id_bitpix  )))) keep(i) = 0n;
    if (is_array((i = where(ids == _fits_id_naxis   )))) keep(i) = 0n;
    if (is_array((i = where(ids == _fits_id_end     )))) keep(i) = 0n;
    if (is_void(bscale) &&
        is_array((i = where(ids == _fits_id_bscale  )))) keep(i) = 0n;
    if (is_void(bzero) &&
        is_array((i = where(ids == _fits_id_bzero   )))) keep(i) = 0n;
    if (is_array((i = where(keep)))) {
      /* Make a dummy FITS handle with cards to keep, perform final cleanup
         on this expurged template, then merge with cards of new handle. */
      template = _lst(_car(template, 1)(i), ids(i), [1, 0, 0, 0, 'r'], []);
      fits_delete, template, "NAXIS#";
      if (is_array((i = where(_car(template, 1))))) {
        if (is_array((j = where(_car(fh, 1))))) {
          j = j(where(_car(fh, 2)(j) != _fits_id_end));
        }
        _car, fh, 1, grow([], _car(fh, 1)(j), _car(template, 1)(i));
        _car, fh, 2, grow([], _car(fh, 2)(j), _car(template, 2)(i));
      }
    }    
    template = [];
  }
  if (! is_void(bscale)) fits_set, fh, "BSCALE", bscale, scale_comment;
  if (! is_void(bzero)) fits_set, fh, "BZERO", bzero, scale_comment;
  for (i=1 ; i<=numberof(history) ; ++i) fits_set, fh, "HISTORY", history(i);
  for (i=1 ; i<=numberof(comment) ; ++i) fits_set, fh, "COMMENT", comment(i);
  return fh;
}

func fits_check_file(filename, errmode)
/* DOCUMENT fits_check_file(filename)
       -or- fits_check_file(filename, errmode)
     Returns 1/0  depending whether FILENAME is  a valid FITS  file or not.
     If ERRMODE is true (non-nil  and non-zero), unreadable file results in
     false result otherwise it is  a runtime error.  Note that the checking
     is very simple: it is sufficient that the first FITS card in the first
     2880 bytes has keyword "SIMPLE" with logical value 'T' (true).

  SEE ALSO: fits. */
{
  stream = open(filename, "rb", errmode);
  if (! stream) return 0n;
  block_size = sizeof((block = array(char, 80, 36)));
  if (_read(stream, 0, block) != block_size) return 0n;
  digit = _fits_digitize(1 + block(1:8,1));
  if (min(digit) < 0 || min((!digit)(dif)) < 0) return 0n;
  id = sum(_fits_multiplier*digit);
  if (id != _fits_id_simple) return 0n;
  value = fits_parse(string(&block(,1)), id, safe=1);
  if (structof(value) != char) return 0n;
  return (value == 'T');
}

func fits_read_header(fh)
/* DOCUMENT fits_read_header(fh)
     (Re)read  and parse  header of  current  HDU of  FITS handle  FH.
     Contents of FH is updated with  header part of new HDU.  To allow
     for linked calls,  the returned value is FH.   If the current HDU
     is empty (i.e. last HDU in the file), the header will be empty.

   SEE ALSO: fits, fits_open, fits_read_array, fits_next_hdu. */
{
  /* Completely read the header: check that the first card is
     SIMPLE or XTENSION and read FITS blocks until the END card is
     encountered. */
  local offset; eq_nocopy, offset, _car(fh,3);
  if (offset(5) != 'r') error, "FITS file not open for reading";
  unit    = offset(1);
  address = offset(2);
  file    = _car(fh,4);
  block_size = sizeof((block = array(char, 80, 36)));
  nblocks = 0;
  hdr = ids = [];
  for (;;) {
    /* Read next header block. */
    if ((nbytes = _read(file, address, block)) != block_size) {
      if (nbytes == 0 && nblocks == 0) {
        offset(4) = offset(3) = offset(2);
        _car, fh, 1, [];
        _car, fh, 2, [];
        return fh;
      }
      error, "cannot read FITS header or keyword END not found";
    }
    ++nblocks;
    address += block_size;

    /* Get numerical ID's of _all_ cards in the new block (I do not use
       fits_id for efficiency reasons and because any errors will be
       raised later). */
    block_id = _fits_id(block);

    /* Check 1st card of 1st header block. */
    if (nblocks == 1) {
      if (block_id(1) < 0.0) error, _fits_bad_keyword(block(1:8, 1));
      id = block_id(1);
      card = string(&block(,1));
      value = fits_parse(card, id, safe=1);
      type = structof(value);
      if (unit == 1) {
        if (id != _fits_id_simple || type != char)
          error, "not a FITS file";
        if (value != 'T') error, "file does not conform to FITS standard";
      } else if (id != _fits_id_xtension || type != string) {
        error, swrite(format="invalid FITS extension (unit=%d)", unit);
      }
    }

    /* Now we can check the validity of FITS keywords. */
    if (min(block_id) < 0.0) {
      /* Bad keyword detected: report first one. */
      error, _fits_bad_keyword(block(1:8, where(block_id < 0.0)(1)));
    }

    /* Search for the END keyword. */
    if (is_array((i = where(block_id == _fits_id_end)))) {
      /* Append last cards and corresponding identifiers, convert
         cards to strings and store things in FITS handle. */
      i = i(1) - 1; /* discard the END card */
      if (i >= 1) {
        grow, hdr, block(,:i);
        grow, ids, block_id(:i);
      }
      block = [];
      if (is_array((i = where(hdr=='\a')))) {
        /* In scan format strings of the parsing routines, I assume that
           the bell character '\a' is never present in a FITS header.  At
           least this character must therefore always be replaced by a
           space. */
        if (_fits_strict) error, "invalid character '\\a' in FITS header";
        hdr(i) = ' ';
      }
      ncards = numberof(ids);
      cards = array(string, ncards);
      for (i=1 ; i<=ncards ; ++i) cards(i) = string(&(hdr(,i)));
      _car, fh, 1, cards;
      _car, fh, 2, ids;
      break;
    }

    /* Grow the card and numerical identifier arrays. */
    grow, hdr, block;
    grow, ids, block_id;
  }

  /* Get minimum header information (possibly fixing location of cards) and
     update offsets. */
  data_size = fits_get_data_size(fh, 1);
  offset(3) = address; /* address of data in current HDU */
  offset(4) = address + ((data_size + block_size - 1)/block_size)*block_size;

  return fh;
}

func fits_goto_hdu(fh, hdu)
/* DOCUMENT fits_goto_hdu(fh, hdu)
     Move FITS handle FH to Header  Data Unit number HDU (starting at 1 for
     the primary HDU) and parse the  header part of the new unit.  Contents
     of FH  is updated with  header part of  new HDU.  To allow  for linked
     calls, the returned value is FH.

   SEE ALSO: fits, fits_next_hdu, fits_read_header, fits_rewind. */
{
  local offset; eq_nocopy, offset, _car(fh,3);
  if (offset(5) != 'r') error, "FITS file not open for reading";
  while (hdu != offset(1)) {
    if (hdu < offset(1)) {
      if (hdu <= 0) error, "bad HDU number";
      offset(1:4) = 0;
    }
    ++offset(1);
    offset(2) = offset(4);
    fits_read_header, fh;
  }
  return fh;
}

func fits_next_hdu(fh)
/* DOCUMENT fits_next_hdu(fh)
     Move FITS handle FH to next Header Data Unit and parse the header part
     of the  new unit.  Contents of FH  is updated with header  part of new
     HDU.  To allow for linked calls, the returned value is FH.

   SEE ALSO: fits, fits_goto_hdu, fits_read_header, fits_rewind. */
{
  local offset; eq_nocopy, offset, _car(fh,3);
  if (offset(5) != 'r') error, "FITS file not open for reading";
  ++offset(1);
  offset(2) = offset(4);
  return fits_read_header(fh);
}

func fits_rewind(fh)
/* DOCUMENT fits_rewind(fh)
     Move FITS handle FH to primary Header Data Unit and parse the header part
     of the unit.  FH is returned when called as a function.

   SEE ALSO: fits, fits_read_header, fits_next_hdu. */
{
  local offset; eq_nocopy, offset, _car(fh,3);
  if (offset(5) != 'r') error, "FITS file not open for reading";
  if (offset(1) == 1) return fh;
  offset(1) = 1;
  offset(2) = 0;
  return fits_read_header(fh);
}

func fits_eof(fh)
/* DOCUMENT fits_eof(fh)
     Returns non-zero if FITS handle FH is at end of file.

   SEE ALSO: fits, fits_open, fits_next_hdu. */
{
  if (_car(fh,3)(5) != 'r') error, "FITS file not open for reading";
  return is_void(_car(fh, 1));
}

func fits_current_hdu(fh) { return _car(fh,3)(1); }
/* DOCUMENT fits_current_hdu(fh);
     Return number of current Header Data Unit in FITS handle FH.

   SEE ALSO: fits, fits_read_header, fits_rewind, fits_next_hdu. */

func fits_list(fh, key)
/* DOCUMENT fits_list, fh;
       -or- fits_list(fh)
     Get the names of  the FITS extensions in FH.  FH can  be the name of a
     FITS file  or a FITS handle  FH (the input handle  is left unchanged).
     When called  as a  subroutine, the list  is printed to  terminal; when
     called as  a function, the returned  value is a string  array with the
     names of the FITS extensions in FH.

   SEE ALSO: fits, fits_read_header, fits_next_hdu. */
{
  /* Get header of primary HDU. */
  if (structof(fh) == string) {
    /* open FITS file for reading */
    fh = fits_open(fh);
  } else {
    /* make private copy of FITS handle */
    if (typeof(fh) != "list" || _len(fh) != 4) error, "bad FITS handle";
    filemode = _car(fh,3)(5);
    stream = _car(fh,4);
    if (filemode != 'r') error, "FITS file not open for reading";
    fh = fits_read_header(_lst([], [], [1, 0, 0, 0, filemode], stream));
  }
  if (is_void(key)) {
    key = _fits_id_xtension;
  } else if (structof(key) == string) {
    key = fits_id(key);
  }
  if (key == _fits_id_xtension || key == _fits_id_extname) {
    result = "IMAGE";
    fits_next_hdu, fh;
  } else {
    result = [];
  }
  while (! is_void(_car(fh,1))) {
    grow, result, fits_get(fh, key);
    fits_next_hdu, fh;
  }
  if (! am_subroutine()) return result;
  if ((s = structof(result)) == string) {
    f = "\"%s\"";
  } else if (s == char || s == short || s == int || s == long) {
    f = "%d";
  } else if (s == float || s == double) {
    f = "%g";
  } else {
    error, "cannot print \""+typeof(result)+"\" result";
  }
  f = swrite(format="  HDU = %%3d   %s = %s\n", fits_key(key), f);
  write, format=f, indgen(numberof(result)), result;
}

func _fits_warn(msg) { write, format="FITS - WARNING: %s\n", msg; }
/* DOCUMENT _fits_warn, msg;
     Private FITS routine: print out warning message MSG. */

func fits_nth(n)
/* DOCUMENT fits_nth(n)
     Returns a string in the form "1st", "2nd", "3rd" or "#th" where # is
     the human readable value of integer N.

   SEE ALSO: fits, fits_set_dims. */
{
  return (n == 1 ? "1st" :
          (n == 2 ? "2nd" :
           (n == 3 ? "3rd" :
            swrite(format="%dth", n))));
}

func fits_date(nil) { return rdline(popen("date -u +%D",0)); }
/* DOCUMENT fits_date()
     Returns current Universal Time date as a string conforming to FITS
     standard: "DD/MM/YY"

   SEE ALSO: fits, rdline, popen. */

func fits_get_bitpix(fh, fix)
/* DOCUMENT fits_get_bitpix(fh)
       -or- fits_get_bitpix(fh, fix)
     Get  BITPIX   value  from  current   HDU  in  FITS  handle   FH.   See
     fits_get_special for the meaning of FIX.

   SEE ALSO: fits, fits_check_bitpix, fits_get_special,
            fits_get_naxis, fits_get_dims. */
{
  bitpix = fits_get_special(fh, "BITPIX", _fits_id_bitpix, 2, fix);
  if (structof(bitpix)!=long || ! fits_check_bitpix(bitpix))
    error, "bad BITPIX value";
  return bitpix;
}

func fits_get_naxis(fh, fix)
/* DOCUMENT fits_get_naxis(fh)
       -or- fits_get_naxis(fh, fix)
     Get  NAXIS   value  from   current  HDU  in   FITS  handle   FH.   See
     fits_get_special for the meaning of FIX.

   SEE ALSO: fits, fits_get_special, fits_get_bitpix, fits_get_dims. */
{
  naxis = fits_get_special(fh, "NAXIS", _fits_id_naxis, 3, fix);
  if (structof(naxis)!=long || naxis<0) error, "bad NAXIS value";
  return naxis;
}

func fits_get_dims(fh, fix)
/* DOCUMENT fits_get_dims(fh)
       -or- fits_get_dims(fh, fix)
     Get all  NAXIS* values from current  HDU in FITS handle  FH and return
     vector  [NAXIS, NAXIS1,  NAXIS2, ...].   If the  value of  any  of the
     "NAXIS#" card is  zero, then there is no data in  the current unit and
     fits_get_dims returns [] (nil) in this case.  See fits_get_special for
     the meaning of FIX.

   SEE ALSO: fits, fits_get_special, fits_get_bitpix, fits_get_naxis. */
{
  naxis = fits_get_naxis(fh, fix);
  if (! naxis) return;
  dims = array(naxis, naxis+1);
  for (ith=1 ; ith<=naxis ; ++ith) {
    key = swrite(format="NAXIS%d", ith);
    id = fits_id(key);
    value = fits_get_special(fh, key, id, 3+ith, fix);
    if (structof(value) != long || value < 0) error, "bad "+key+" value";
    dims(ith+1) = value;
  }
  if (nallof(dims)) return; /* empty data */
  return dims;
}

func fits_get_xtension(fh)
/* DOCUMENT fits_get_xtension(fh)
     Get XTENSION value  from current HDU in FITS  handle FH.  The returned
     value is a  scalar string with the name of  the extension;  "IMAGE" is
     returned for the primary HDU.

   SEE ALSO: fits, fits_get, fits_parse. */
{
  location = 1;
  hdu = _car(fh,3)(1);
  id = _car(fh,2)(location);
  value = fits_parse(_car(fh,1)(location), id);
  if (hdu == 1) {
    if (id == _fits_id_simple && structof(value) == char && value == 'T')
      return "IMAGE";
    error, "not a valid FITS file";
  }
  if (hdu > 1) {
    if (id == _fits_id_xtension && structof(value) == string) return value;
    error, "bad/missing XTENSION card in FITS header";
  }
  error, "bad unit number in FITS handle";
}

func fits_get_special(fh, key, id, location, fix)
/* DOCUMENT fits_get_special(fh, key, id, location, fix)
     Get  value of  a special  FITS card  given its  key  string, numerical
     identifier and absolute  LOCATION (1 for first FITS  card).  If FIX is
     true,  various further  verifications  are made  and,  if FITS  strict
     checking mode is  off, the header may be fixed  in case of unambiguous
     error.

   SEE ALSO: fits, fits_get_bitpix, fits_get_naxis, fits_get_dims
             fits_parse. */
{
  if (is_void(id)) id = fits_id(key);
  if (fix) {
    if (! is_array((i = where(_car(fh,2) == id))))
      error, key+" card not found in FITS header";
    if (numberof(i) != 1)
      error, "too many "+key+" cards in FITS header";
    i = i(1);
    if (i != location) {
      if (_fits_strict) error, "wrong location of "+key+" card in FITS header";
      fits_move_card, fh, i, location;
    }
  } else if (_car(fh,2)(location) != id) {
    error, key+" card not found in FITS header";
  }
  return fits_parse(_car(fh,1)(location), id);
}

local fits_coordinate;
func fits_get_coordinate(fh, axis, span=)
/* DOCUMENT fits_get_coordinate(fh, axis)
     Gets AXIS-th coordinate information for current HDU in FITS handle FH.
     By  default, the  result  is a  fits_coordinate  structure defined  as
     follows:
       struct fits_coordinate {
         long axis;    // axis number
         long length;  // number of elements along this axis
         string ctype; // name of the coordinate represented by this axis
         double crpix; // location of a reference point (starting at 1)
                       // along this axis
         double crval; // value of the coordinate along this axis at the
                       // reference point
         double cdelt; // partial derivative of the coordinate with respect
                       // to the pixel index along this axis, evaluated at
                       // the reference point
         double crota; // used to indicate a rotation from a standard
                       // coordinate system described by the value of CTYPE
                       // to a different coordinate system in which the
                       // values in the array are actually expressed
       }

     If keyword  SPAN is true, then the  result is a vector  that gives the
     coordinate of each element along given axis:
        CDELT*(indgen(LENGTH) - CRPIX) + CRVAL
     Note that, if the axis length is zero, a nil value is returned.

   SEE ALSO: fits, fits_get, fits_get_dims. */
{
  if (! fits_is_integer_scalar(axis))
    error, "AXIS number must be a scalar integer";
  ith = swrite(format="%d", axis);
  if (structof((length = fits_get(fh, (key = "NAXIS"+ith)))) != long ||
      length < 0) error, ((is_void(length) ? "missing" : "bad value/type for")
                          + " FITS card \"" + key + "\"");
  if (structof((crpix = fits_get(fh, (key = "CRPIX"+ith),
                                 default=1.0))) != double ||
      structof((crval = fits_get(fh, (key = "CRVAL"+ith),
                                 default=1.0))) != double ||
      structof((cdelt = fits_get(fh, (key = "CDELT"+ith),
                                 default=1.0))) != double ||
      structof((crota = fits_get(fh, (key = "CROTA"+ith),
                                 default=0.0))) != double ||
      structof((ctype = fits_get(fh, (key = "CTYPE"+ith),
                                 default=string(0)))) != string)
    error, "bad data type for FITS card \"" + key + "\"";
  if (span) return (length ? cdelt*(indgen(length) - crpix) + crval : []);
  return fits_coordinate(axis=axis, length=length, ctype=ctype,
                         crpix=crpix, crval=crval, cdelt=cdelt, crota=crota);
}
struct fits_coordinate {
  long axis, length;
  string ctype;
  double crpix, crval, cdelt, crota;
}

func fits_get_keywords(fh, ordered)
/* DOCUMENT fits_get_keywords(fh)
       -or- fits_get_keywords(fh, ordered)
     Get list  of FITS keywords defined  in current HDU of  FITS handle HF.
     The returned value is an array of strings. If ORDERED is true (non-nil
     and non-zero),  the keywords get  sorted.  Note: the "END"  keyword is
     always missing in a (non-corrupted) FITS handle.

   SEE ALSO: fits, sort, strtok. */
{
  local cards; eq_nocopy, cards, _car(fh,1);
  if (is_void(cards) || ! is_array((i = where(cards)))) return;
  s = strtok(strpart(cards(i), 1:8))(1,);
  return (ordered ? s(sort(s)) : s);
}

/*---------------------------------------------------------------------------*/
/* EDITION OF HEADER */

func fits_move_card(fh, from, to)
/* DOCUMENT fits_move_card(fh, from, to);
     Change location of FROM-th card to  index TO into FITS handle FH.  The
     operation is made in place.

   SEE ALSO: fits, fits_move. */
{
  fits_move, _car(fh,1), from, to;
  fits_move, _car(fh,2), from, to;
}

func fits_move(a, i, j)
/* DOCUMENT fits_move, a, i, j;
     Move I-th element of array A  in place of J-th element.  The operation
     is done in-place.

   SEE ALSO: fits, fits_move_card. */
{
#if 0
  n = numberof(a);
  if (i <= 0) i += n;
  if (j <= 0) j += n;
#endif
  if (i < j) {
    t = a(i);
    a(i:j-1) = a(i+1:j);
    a(j) = t;
  } else if (i > j) {
    t = a(i);
    a(j+1:i) = a(j:i-1);
    a(j) = t;
  }
}

func fits_write_header(fh)
/* DOCUMENT fits_write_header(fh)
     Write  header  information of  FITS  handle  FH  into current  HDU  of
     associated file.   It is possible to  re-write header as  long as this
     would not overwrite existing written data if any (i.e. the new header,
     rounded up  to a multiple of 2880  bytes, must not be  longer than the
     old one or there must be no data written.

   SEE ALSO: fits, fits_open, fits_write, fits_write_array. */
{
  local cards, ids; _fits_get_cards, fh, cards, ids;
  local offset; eq_nocopy, offset, _car(fh, 3);
  stream = _car(fh, 4);
  if (offset(5) != 'w' /* FIXME: && offset(5) != 'a' */)
    error, "FITS file not open for writing/appending";

  /* Locate last FITS card. */
  if (is_array((i = where(ids == _fits_id_end)))) {
    /* keyword "END" already in header */
    last = i(1);
  } else {
    /* "END" card will be appended automatically */
    i = where(cards);
    last = (is_array(i) ? i(0) : 0) + 1;
  }

  /* Compute number of header cards to write. */
  no_data = (offset(4) <= offset(3));
  if (no_data) {
    /* Round up the number of cards to write to a multiple of 36. */
    ncards = ((last + 35)/36)*36;
  } else {
    /* Data already written in file.  Check that writing header will not
       overwrite any data. */
    nbytes = offset(3) - offset(2); /* size of written header */
    if (nbytes % 2880) error, "corrupted FITS handle";
    if (nbytes < last*80)
      error, "overwriting current header would overwrite data";
    ncards = nbytes/80;
  }

  /* Convert textual header to bytes. */
  hdr = array(' ', 80, ncards);
  for (k=1 ; k<last ; ++k) {
    s = cards(k);
    if ((l = strlen(s)) >= 1) {
      rng = 1:min(l, 80);
      hdr(rng, k) = (*pointer(s))(rng);
    }
  }
  hdr(1, last) = 'E';
  hdr(2, last) = 'N';
  hdr(3, last) = 'D';

  /* Write header and update offset information. */
  address = offset(2);
  _write, stream, address, hdr;
  offset(3) = address + sizeof(hdr);
  if (no_data) offset(4) = offset(3);
  return fh;
}

//func _fits_check_offset(offset)
//{
//  n1 = offset(3) - offset(2);
//  n2 = offset(4) - offset(3);
//  if (n1 < 0 || n1 % 2880 || n2 < 0 || n2 % 2880)
//    error, "corrupted FITS handle";
//  return [n1, n2];
//}

func fits_get_data_size(fh, fix)
/* DOCUMENT fits_get_data_size(fh)
       -or- fits_get_data_size(fh, fix)
     Computes  the number  of bytes  in data  part of  current HDU  of FITS
     handle FH.  This value is computed  according to the header part of FH
     and may be different from the  number of bytes actually written in the
     data part of the current HDU.

   SEE ALSO: fits, fits_read_header. */
{
  bitpix = fits_get_bitpix(fh, fix);
  dims   = fits_get_dims(fh, fix);
  gcount = fits_get_gcount(fh);
  pcount = fits_get_pcount(fh);
  if (is_void(dims)) {
    naxis = 0;
    ndata = 0;
  } else {
    naxis = dims(1);
    i = numberof(dims);
    ndata = 1;
    while (i > 1) ndata *= dims(i--);
  }
  return (abs(bitpix)/8)*gcount*(pcount + ndata);
}

/*             input              output
 * offset(1) = HDU                (unchanged)
 * offset(2) = header offset      (unchanged)
 * offset(3) = data offset        (unchanged)
 * offset(4) = file size          next header offset
 * offset(5) = file mode          (unchanged)
 */
func fits_pad_hdu(fh)
/* DOCUMENT fits_pad_hdu(fh)

     Fix file size in handle FH to a multiple of FITS blocking factor (2880
     bytes) by writting null or space characters at the end of the file and
     update FH offsets accordingly.  FH must be open for writing.

   SEE ALSO: fits, fits_close, fits_new_hdu. */
{
  /* Check offsets and sizes of header and data parts. */
  local offset; eq_nocopy, offset, _car(fh, 3);
  if (offset(5) != 'w') error, "FITS file not open for writing";
  BLOCKSIZE = 2880; /* FITS blocking factor */
  if (min(offset) < 0 || (header_offset = offset(2)) % BLOCKSIZE ||
      (data_offset = offset(3)) % BLOCKSIZE ||
      (file_size = offset(4)) < data_offset || data_offset < header_offset) {
    error, "corrupted FITS handle";
  }
  if (data_offset <= header_offset) {
    error, "no header written";
  }
  if (file_size - data_offset < fits_get_data_size(fh)) {
    error, "no data written or short data part";
  }
  
  /* Possibly pad file with null bytes or spaces. */
  rounded_size = ((file_size + BLOCKSIZE - 1)/BLOCKSIZE)*BLOCKSIZE;
  if (rounded_size > file_size) {
    pad = char((fits_get_xtension(fh) == "TABLE" ? ' ' : 0));
    _write, _car(fh, 4), file_size, array(pad, rounded_size - file_size);
    offset(4) = rounded_size; /* update file size */
  }
  return fh;
}

func fits_new_hdu(fh, xtension, comment)
/* DOCUMENT fits_new_hdu(fh, xtension)
       -or- fits_new_hdu(fh, xtension, comment)       
     Starts a new extension in FITS  file open for writing.  FH is the FITS
     handle, XTENSION is  the name of the FITS extension  and COMMENT is an
     optional string comment.  After calling fits_new_hdu, there is no need
     to call:

       fits_set, FH, "XTENSION", XTENSION, COMMENT;

     since this is already done by this routine.  However, beware that FITS
     standard requires that, if any  extension is present in the file, that
     the keyword "EXTEND" with logical  value 'T' (true) must appear in the
     primary header.


   SEE ALSO: fits, fits_pad_hdu, fits_set,
             fits_write_header, fits_write_array. */
{
  /* Minimal check to avoid errors which would left a
     corrupted handle after the final fits_set. */
  if (! fits_is_string_scalar(xtension)) {
    error, "extension must be a scalar string";
  }
  if (! is_void(comment) && ! fits_is_string_scalar(comment)) {
    error, "comment must be nil or a scalar string";
  }

  local offset;
  fits_pad_hdu, fh; /* round up file size and clash if invalid mode */
  eq_nocopy, offset, _car(fh, 3);
  if (offset(1) == 1 && fits_get(fh, "EXTEND", default='F') != 'T')
    error, "primary header must set EXTEND='T' to allow for extensions";
  offset(2) = offset(3) = offset(4); /* update file offsets */
  ++offset(1); /* increment HDU number */
  _car, fh, 1, []; /* clear cards */
  _car, fh, 2, []; /* clear keys */
  return fits_set(fh, "XTENSION", xtension, comment);
}

/*---------------------------------------------------------------------------*/
/* SETTING VALUE OF FITS CARDS */

func fits_set(fh, key, value, comment)
/* DOCUMENT fits_set, fh, key, value;
       -or- fits_set, fh, key, value, comment;
     Set (or adds) FITS card in header  of FITS handle FH.  KEY is the card
     name (FITS keyword)  and must be a scalar string,  VALUE is the scalar
     value of the card and COMMENT is an optional string comment.

     Commentary cards -- for which KEY  is one of "COMMENT, "HISTORY" or ""
     (blank) -- get appended to the  existing cards in the header of FH (if
     the VALUE of a commentary card is too long, it may occupy several FITS
     cards).   For any  other  kind of  cards,  the new  card replaces  the
     existing one, if any; or  get appended to the existing cards.  Special
     cards that must appear in a precise order ("SIMPLE", "BITPIX", "NAXIS"
     and "NAXIS#") must  be added in the correct order  (their value can be
     modified afterward).  The "END"  card is not  needed since it  will be
     automatically written when required.


   SEE ALSO: fits, fits_open. */
{
  /* Fix FITS card name and get its numerical identifier. */
  if (! fits_is_string_scalar(key)) error, "expecting a scalar string for KEY";
  key = _fits_key((id = fits_id(key)));

  /* Check other arguments. */
  s = structof(value);
  if (s == string) {
    op = _fits_format_string;
  } else if (s == long || s == int || s == short) {
    op = _fits_format_integer;
  } else if (s == double || s == float) {
    op = _fits_format_real;
  } else if (s == complex) {
    op = _fits_format_complex;
  } else if (s == char) {
    if (dimsof(value)(1) || (value != 'T' && value != 'F'))
      error, "FITS logical value for card \""+key+"\" must be 'T' or 'F'";
    op = _fits_format_logical;
  } else {
    /* Do nothing for "END" card. */
    if (is_void(value) && id == _fits_id_end) {
      if (is_void(comment)) return fh;
      error, "FITS \"END\" card takes no value nor comments";
    }
    error, "unsupported type \""+typeof(value)+"\" for FITS card \""+key+"\"";
  }
  if (! fits_is_scalar(value)) error, "expecting a scalar VALUE";
  if (! is_void(comment) && ! fits_is_string_scalar(comment))
    error, "optional COMMENT must be a scalar string";

  /* Format card and figure out its location (LOCATION > 0 for cards that
     must be at a given position, LOCATION = -1 for commentary cards and
     LOCATION = 0 for other cards). */
  errfmt = "invalid value/type for FITS card \"%s\"";
  if (anyof(id == _fits_id_special)) {
    /* Deal with special keywords. */
    if (id == _fits_id_simple) {
      if (op != _fits_format_logical) error, swrite(format=errfmt, key);
      location = 1;
    } else if (id == _fits_id_xtension) {
      if (op != _fits_format_string) error, swrite(format=errfmt, key);
      location = 1;
    } else if (id == _fits_id_bitpix) {
      if (op != _fits_format_integer || ! fits_check_bitpix(value))
        error, swrite(format=errfmt, key);
      location = 2;
    } else if (id == _fits_id_naxis) {
      if (op != _fits_format_integer || value < 0)
        error, swrite(format=errfmt, key);
      location = 3;
    } else if (id == _fits_id_comment || id == _fits_id_history || id == 0.0) {
      if (! is_void(comment))
        error, "too many arguments for commentary FITS card";
      if (op != _fits_format_string) error, swrite(format=errfmt, key);
      op = _fits_format_comment;
      location = -1; /* append after last valid card */
    } else {
      /* Must be "END" keyword (which is already checked above so it must
         be an error here). */
      error, "FITS \""+key+"\" card takes no value nor comments";
    }
  } else {
    location = 0;
    if (strpart(key, 1:5) == "NAXIS") {
      n = 0;
      s = string(0);
      if (sread(key, format="NAXIS%d%s", n, s) == 1 && n >= 1) {
        if (op != _fits_format_integer || value < 0)
          error, swrite(format=errfmt, key);
        location = 3 + n;
      }
    }
  }
  card = op(key, value, comment);

  /* Get card(s) and numerical identifiers in header. */
  local cards, ids;
  ncards = _fits_get_cards(fh, cards, ids);

  /* Maybe replace existing FITS card. */
  if (location >= 0 && ncards) {
    if (location > 0) {
      if (location <= ncards && ids(location) == id) {
        cards(location) = card;
        return fh;
      }
    } else if (is_array((i = where(ids == id)))) {
      cards(i(1)) = card;
      return fh;
    }
  }

  /* At this point we have to append the card(s) after the last one. */
  n = numberof(card);
  nfree = (ncards ? numberof((i = where(! cards))) : 0);
  if (nfree < n) {
    /* round up the new number of cards to a multiple of 36 cards */
    new = ((ncards + n - nfree + 35)/36)*36 - ncards;
    _, cards, array(string, new); _car, fh, 1, cards;
    _,   ids, array(-1.0,   new); _car, fh, 2,   ids;
    i = where(! cards);
  }
  j = i((n > 1 ? indgen(n) : 1));
  if (location > 0 && location != j) {
    error, swrite(format="FITS card \"%s\" must be written at index %d",
                  key, location);
  }
  cards(j) = card;
  ids(j) = id;
  return fh;
}

func _fits_get_cards(fh, &cards, &ids)
/* DOCUMENT _fits_get_cards(fh, cards, ids)
     Stores  in  variables CARDS  and  IDS  the  FITS cards  and  numerical
     identifiers from header in FITS  handle FH.  The returned value is the
     number of FITS cards (including empty ones).

   SEE ALSO: fits, fits_set. */
{
  eq_nocopy, cards, _car(fh, 1);
  eq_nocopy,   ids, _car(fh, 2);
  if ((ncards = numberof(cards)) != numberof(ids)) {
    _fits_warn, "corrupted FITS handle, trying to fix it...";
    fits_rehash, fh;
    eq_nocopy,   ids, _car(fh, 2);
  }
  return ncards;
}

/* FITS card format:
 *       bytes   description
 *      ------   ------------------------------------------------------------
 *        1:8  = keyword
 *        9:10 = value indicator "= "
 *       11:80 = value / comment
 *
 * STRING value format:
 *       bytes   description
 *      ------   ------------------------------------------------------------
 *          11 = ' (quote)
 *    11+(1:N) = string value, 8<=N<=68 (with quotes doubled, and padded with
 *               spaces to have N>=8, trailing spaces are not significant,
 *               leading spaces are significant)
 *        12+N = ' (quote)
 *
 * LOGICAL value format:
 *       bytes   description
 *      ------   ------------------------------------------------------------
 *       11:29 = spaces
 *          30 = T or F
 */

func _fits_format_logical(key, value, comment)
/* DOCUMENT _fits_format_logical(key, value)
       -or- _fits_format_logical(key, value, comment)
     Private  routine to format  FITS logical  card, return  a 80-character
     string.

   SEE ALSO: fits, fits_set. */
{
  if (value=='T') value= "T";
  else if (value=='F') value= "F";
  else error, "invalid logical value for FITS card \""+key+"\"";
  return strpart(swrite(format="%-8s= %20s / %-47s",
                        key, value, (is_void(comment)?"":comment)), 1:80);
}

func _fits_format_integer(key, value, comment)
/* DOCUMENT _fits_format_integer(key, value)
       -or- _fits_format_integer(key, value, comment)
     Private routine to format FITS integer card, return a 80-character
     string.

   SEE ALSO: fits, fits_set. */
{
  return strpart(swrite(format="%-8s= %20d / %-47s",
                        key, value, (is_void(comment)?"":comment)), 1:80);
}

func _fits_format_real(key, value, comment)
/* DOCUMENT _fits_format_real(key, value)
       -or- _fits_format_real(key, value, comment)
     Private routine to format FITS real card, return a 80-character
     string.

     Note: FITS standard imposes that the ASCII representation of a real
           number makes 20 characters;  the full precision of 64-bit values
           can not be represented with this restriction.

   SEE ALSO: fits, fits_set. */
{
  /* With exponential representation, the maximum number of significant digit
     is LEN-7=13 hence the %20.12E format */
  return strpart(swrite(format="%-8s= %20.12E / %-47s",
                        key, value, (is_void(comment)?"":comment)), 1:80);
}

func _fits_format_complex(key, value, comment)
/* DOCUMENT _fits_format_complex(key, value)
       -or- _fits_format_complex(key, value, comment)
     Private routine to format FITS complex card, return a 80-character
     string.

   SEE ALSO: fits, fits_set. */
{
  return strpart(swrite(format="%-8s= %20.12E%20.12E / %-27s",
                        key, value.re, value.im,
                        (is_void(comment)?"":comment)), 1:80);
}

func _fits_format_string(key, value, comment)
/* DOCUMENT _fits_format_string(key, value)
       -or- _fits_format_string(key, value, comment)
     Private routine to format FITS string card, return a 80-character
     string.

     Note: enclose input string in quotes, replacing each quote in input
           string by 2 quotes.  Since opening quote should appear in
           column 11 and closing quote in columns 20 to 80 of the FITS
           card, make sure that string is not longer than 68 characters
           (too long strings get silently truncated).

   SEE ALSO: fits, fits_set. */
{

  /* Replace every quote character (ASCII 0x27) in VALUE by two quotes and
     make sure the result is not longer than 68 characters. */
  len = strlen(value);
  src = *pointer(value);
  dst = array(char, 2*len + 1);
  i = j = 0;
  n = min(34, len);
  while (i < n) {
    /* faster loop: no need to check length of result */
    if ((c = src(++i)) == '\'') dst(++j) = '\'';
    dst(++j) = c;
  }
  while (i < len) {
    /* slower loop: need to check length of result */
    if ((c = src(++i)) == '\'') {
      if (j >= 67) break;
      dst(++j) = '\'';
    } else if (j >= 68) break;
    dst(++j) = c;
  }
  value = swrite(format="'%-8s'", string(&dst));
  return strpart(swrite(format="%-8s= %-20s / %-47s",
                        key, value, (is_void(comment)?"":comment)), 1:80);
}

func _fits_format_comment(key, text, unused)
/* DOCUMENT _fits_format_comment(key)
       -or- _fits_format_comment(key, text)
     Private routine  to format  FITS commentary card,  return an  array of
     80-character string(s).   Text comment, if longer  than 72 characters,
     will result in more than one comment cards.

   SEE ALSO: fits, fits_set. */
{
  len = strlen(text);
  if (len <= 72) {
    if (! len) return swrite(format="%-80s", key);
    return swrite(format="%-8s%-72s", key, text);
  }
  n = (len + 71)/72;
  card = array(string, n);
  text += swrite(format="%71s", "");
  for (i=1, j=1 ; i<=n ; ++i, j+=72) card(i) = strpart(text, j:j+71);
  return swrite(format="%-8s", key)+card;
}

/*---------------------------------------------------------------------------*/
/* IMAGE/ARRAY DATA */

func fits_read_array(fh, which=, rescale=)
/* DOCUMENT fits_read_array(fh)
     Gets "image" (actually a Yorick array) from current HDU of FITS handle
     FH.  Note that the result may be [] (nil) if the current unit contains
     no data.

     Keyword  WHICH may  be  used  to indicate  which  sub-array should  be
     returned.  WHICH always  applies to the last dimension  of the "image"
     data  stored in current  HDU.  For  instance, if  the array  DATA with
     dimensions  (235,453,7)  is  stored  in  the  current  FITS  HDU,  the
     sub-array DATA(,,4) can be obtained by:

         fits_read_array(FH, which=4);

     If keyword RESCALE is true,  returned values get rescaled according to
     FITS keywords BSCALE and BZERO.  If RESCALE=2 and one of BSCALE and/or
     BZERO exists in  the FITS header and  BITPIX was 8, 16, 32,  or -32, a
     single precision  array (float)  is returned.  If  RESCALE is  not set
     (nil), the  default is to  rescale data values  if BSCALE is not  1 or
     BZERO is not  0 (i.e. the default is RESCALE=1).  In  order to get raw
     data (i.e. as written in the file), use RESCALE=0.

   SEE ALSO: fits, fits_open. */
{
  local offset; eq_nocopy, offset, _car(fh,3);
  if (offset(5) != 'r') error, "FITS file not open for reading";
  dims = fits_get_dims(fh, 1);
  if (is_void(dims)) return; /* no data */
  if (is_void(which)) {
    which = 0;
  } else {
    if (! fits_is_integer_scalar(which))
      error, "WHICH must be a scalar integer";
    last = dims(0);
    if (which <= 0)
      which += last;
    if (which > last || which < 1)
      error, "WHICH out of range";
    dims = dims(:-1);
    dims(1) -= 1;
  }
  bitpix = fits_get_bitpix(fh, 1);
  if (bitpix == 8) {
    data_type = char;
    data_size = 1;
  } else if (bitpix == 16) {
    data_type = short;
    data_size = 2;
  } else if (bitpix == 32) {
    data_type = long;
    data_size = 4;
  } else if (bitpix == -32) {
    data_type = float;
    data_size = 4;
  } else if (bitpix == -64) {
    data_type = double;
    data_size = 8;
  } else {
    error, "congratulations: you have found a BUG!";
  }
  data = array(data_type, dims);
  address = offset(3);
  if (which > 1) address += (which - 1)*numberof(data)*data_size;
  if (_read(_car(fh,4), address, data) != numberof(data))
    error, "cannot read data";

  /* Possibly rescale pixel values. */
  if (is_void(rescale) || rescale) {
    if ((bscale = fits_get_bscale(fh)) != 1.0) data *= bscale;
    if ((bzero  = fits_get_bzero(fh)) != 0.0) data += bzero;
    if (rescale == 2 && abs(bitpix) <= 32 && structof(data) == double) {
      return float(data);
    }
  }
  return data;
}

func fits_write_array(fh, data, which=, rescale=)
/* DOCUMENT fits_write_array, fh, data;
     Write  array DATA  into  curent HDU  of  FITS handle  FH.   DATA is  a
     so-called "image"  in FITS jargon but  it can be a  numerical array of
     any-dimension.   FITS cards BITPIX,  BSCALE and  BZERO are  taken into
     account to convert data values into file values.  The file values are:

         (DATA  - BZERO)/BSCALE

     with BZERO=0 and  BSCALE=1 by default (i.e. if not found  in FH) or if
     keyword RESCALE  is explicitely set  to zero.  The values  are further
     subject to rounding  to the nearest integer and  clipping for positive
     BITPIX.  If  keyword RESCALE is  explicitely set to false  (zero), the
     file values get written without BSCALE/BZERO scale conversion.

     The N dimensions of DATA must  match the values of the NAXIS1, NAXIS2,
     ..., NAXISn  cards of  the FITS  file (it is  assumed that  the header
     information  stored in  FH  are synchronized  to  the header  actually
     written) extra dimensions in the  FITS file are considered as possible
     data slices.  By  default, the first data slice  get written.  Keyword
     WHICH may be used to write a given slice of data.  The value WHICH may
     be less or equal zero to choose  a slice with respect to the last one.

  EXAMPLE:
     The following  example creates a FITS file  with a 100-by-45-by-4-by-7
     "image" data made of random  values computed and written one 100-by-45
     slice at a time:

       fh = fits_create("newfile.fits", bitpix=16, dimlist=[4,100,45,4,7],
                        bscale=1e-4, bzero=0.0);
       fits_write_header, fh;
       nslices = 4*7; // product of last FITS dimensions
       for (i=1 ; i<=nslices ; ++i)
         fits_write_array, fh, random(100, 45), which=i;
       fits_close, fh;
                        

   SEE ALSO: fits, fits_write, fits_write_header. */
{
  local offset; eq_nocopy, offset, _car(fh, 3);
  stream = _car(fh, 4);
  if (offset(5) != 'w' && offset(5) != 'a')
    error, "FITS file not open for writing/appending";
  if ((n1 = offset(3) - offset(2)) < 0 || n1 % 2880 ||
      (n2 = offset(4) - offset(3)) < 0) error, "corrupted FITS handle";
  if (n1 == 0) error, "no header written";

  /* Check data type and dimension list. */
  data_type = structof(data);
  if (data_type != char && data_type != short && data_type != int &&
      data_type != long && data_type != float && data_type != double) {
    error, "bad data type for FITS array";
  }
  file_dims = fits_get_dims(fh);
  data_dims = dimsof(data);
  file_ndims = file_dims(1);
  data_ndims = data_dims(1);
  if (data_ndims > file_ndims) error, "too many dimensions in DATA";
  for (i=1 ; i<=data_ndims ; ++i) {
    if (data_dims(i+1) != file_dims(i+1))
      error, fits_nth(i)+" dimension of data does not match that of FITS file";
  }
  nslices = 1;
  for (i=data_ndims+1 ; i<=file_ndims ; ++i) nslices *= file_dims(i+1);
  if (is_void(which)) {
    which = 1;
  } else {
    if (! fits_is_integer_scalar(which)) error, "WHICH must be integer scalar";
    if (which <= 0) which += nslices;
    if (which <= 0 || which > nslices) error, "bad value for WHICH";
  }

  /* Convert data according to BITPIX, BSCALE and BZERO. */
  if (is_void((bitpix = fits_get_bitpix(fh))))
    error, "missing BITPIX card in FITS header";
  if (is_void(rescale) || rescale) {
    if ((bzero = fits_get_bzero(fh)) != 0.0) data -= double(bzero);
    if ((bscale = fits_get_bscale(fh)) != 1.0) data *= 1.0/bscale;
    data_type = structof(data); /* may have changed because of BSCALE/BZERO */
  }
  if (bitpix > 0) {
    /* Integer type. */
    if (data_type == double || data_type == float) {
      /* round to nearest integer */
      data = floor(data + 0.5);
      data_type = structof(data); /* should be "double" now */
    }
    if (bitpix == 8) {
      file_type = char;
      file_min = 0;
      file_max = 255;
    } else if (bitpix == 16) {
      file_type = short;
      file_min = -32768;
      file_max =  32767;
    } else if (bitpix == 32) {
      file_type = long;
      file_min = -2147483648;
      file_max =  2147483647;
    } else {
      error, "bad BITPIX value in FITS header";
    }
    if (file_type != data_type) {
      if (min(data) < file_min || max(data) > file_max) {
        _fits_warn, "truncating data values outside range allowed by BITPIX";
        data = file_type(min(max(data, file_type(file_min)),
                             file_type(file_max)));
      } else {
        data = file_type(data);
      }
    }
  } else {
    /* Floating point type. */
    if (bitpix == -32) {
      if (data_type != float) data = float(data);
    } else if (bitpix == -64) {
      if (data_type != double) data = double(data);
    } else {
      error, "bad BITPIX value in FITS header";
    }
  }

  /* Write data and update offsets (note: the padding to a multiple of 2880
     bytes will be done when creating next HDU with fits_new_hdu). */
  data_size = sizeof(data);
  address = offset(3);
  if (which != 1) {
    address += (which - 1)*data_size;
    if (address > offset(4)) /* pad file with null's */
      _write, stream, offset(4), array(char, address - offset(4));
  }
  _write, stream, address, data;
  offset(4) = max(offset(4), address + data_size);
  return fh;
}

func fits_set_dims(fh, dimlist)
/* DOCUMENT fits_set_dims(fh, dimlist)
      Set NAXIS  and NAXIS1,  NAXIS2, ... values  into current HDU  of FITS
      handle FH according to dimension list DIMLIST.  DIMLIST may be empty.

   SEE ALSO: fits, fits_get_dims. */
{
  if (is_void(dimlist)) {
    fits_set, fh, "NAXIS", 0, "this HDU contains no data";
  } else {    
    if ((s = structof(dimlist)) != long && s != int && s != short && s != char)
      error, "non-integer data type for DIMLIST";
    n = dimsof(dimlist)(1);
    if (n == 0) {
      naxis = 1;
    } else if (n == 1 && allof(dimlist >= 1) &&
               (naxis = dimlist(1)) == numberof(dimlist) - 1) {
      dimlist = dimlist(2:);
    } else {
      error, "bad dimension list DIMLIST";
    }
    fits_set, fh, "NAXIS", naxis, "number of dimensions";
    for (k=1 ; k<=naxis ; ++k) {
      fits_set, fh, swrite(format="NAXIS%d", k), dimlist(k),
        "length of " + fits_nth(k) + " dimension";
    }
  }
  return fh;
}

func fits_new_image(fh, data, bitpix=, dimlist=, bzero=, bscale=)
/* DOCUMENT fits_new_image(fh, data)
       -or- fits_new_image(fh, bitpix=..., dimlist=...)
     Starts a new image (array) FITS extension in handle FH and returns FH.
     This routine starts a new FITS extension with name "IMAGE" and pre-set
     FITS cards  needed to describe  the array data according  to keywords:
     BITPIX, DIMLIST, BZERO, and BSCALE.   If argument DATA is given, it is
     used  to guess  the  bits per  pixel  and the  dimension  list if  not
     specified by the keywords BITPIX and DIMSLIST respectively.
     
   SEE ALSO: fits, fits_write_array. */
{
  fits_new_hdu, fh, "IMAGE", "this HDU contains FITS image extension";
  if (! is_void(data)) {
    if (is_void(bitpix)) bitpix = fits_bitpix_of(data);
    if (is_void(dimlist)) dimlist = dimsof(data);
  }
  fits_set, fh, "BITPIX", bitpix, fits_bitpix_info(bitpix);
  fits_set_dims, fh, dimlist;
  if (! is_void(bzero)) fits_set, fh, "BZERO", bzero,
                          "data_value = BZERO + BSCALE*file_value";
  if (! is_void(bscale)) fits_set, fh, "BSCALE", bscale,
                           "data_value = BZERO + BSCALE*file_value";
  return fh;
}

/*---------------------------------------------------------------------------*/
/* BINARY TABLE */

func fits_new_bintable(fh, comment)
/* DOCUMENT fits_new_bintable(fh)
       -or- fits_new_bintable(fh, comment)
       
     Starts a new  binary table FITS extension.  This  routine starts a new
     FITS extension with  name "BINTABLE" and pre-set FITS  cards needed to
     describe the  table with fake values  (the correct values  will be set
     when  fits_write_bintable  is called  to  actually  write the  table).
     After calling this  routine, the user can add new  FITS cards (but not
     XTENSION,  BITPIX,   NAXIS,  NAXIS1,  NAXIS2,   GCOUNT,  nor  PCOUNT).
     Optional argument COMMENT is the comment string for the XTENSION card.

     The returned value is FH.

   SEE ALSO: fits, fits_write_bintable. */
{
  fits_new_hdu, fh, "BINTABLE",
    (is_void(comment) ? "this HDU contains FITS binary table extension"
                      : comment);
  _fits_bintable_header, fh, 0, 0, 0;
  return fh;
}

func fits_write_bintable(fh, ptr, logical=)
/* DOCUMENT fits_write_bintable(fh, ptr)
     Writes contents  of pointer PTR in  a binary table in  FITS handle FH.
     Arrays pointed  by PTR  become the  fields of the  table (in  the same
     order as  in PTR) and must  all have 1  or 2 dimensions with  the same
     first  dimension  (i.e. the  number  of  rows  in the  table),  second
     dimensions can have any values and may all be different: they count as
     the number of 'columns' of the field.  In other words:

       *PTR(i) = i-th  field  in the table,  is an  NROWS-by-NCOLS(i) array
                 where  NROWS  is the  number  of  rows  in the  table  and
                 NCOLS(i) is  the repeat  count of the  i-th field;  it can
                 also be simply a NROWS element vector if NCOLS(i) = 1.
     
     In the current  version of the routine, only  arrays of numbers (char,
     short, int,  long, float,  double or complex)  and vectors  of strings
     (you  can  use several  vectors  to  circumvent  this limitation)  are
     supported.  Before writing  the data part of a  binary table, you must
     creates proper header:

        fits_new_bintable, fh;        // starts a new binary table
        fits_set, fh, "...", ...;     // (optional) set more info. in header
        fits_set, ...;
        fits_write_bintable, fh, ptr; // write binary table

     fits_write_bintable automatically  guess the  format of the  fields in
     the binary table and accordingly set FITS cards "TFORM#" (with # equal
     to the field number) in the header of the binary table.

     If keyword LOGICAL is true (non nil and non-zero) then arrays of int's
     in  PTR  are considered  as  logical arrays  and  saved  as arrays  of
     characters: 'F' for false, 'T' for true or '\0' for bad/invalid value.
     Following Yorick's convention, a "false"  value is integer zero in the
     arrays of  int's and  a "true" is  any non-zero integer.   However, if
     LOGICAL has the  special value 2, then strictly  positive integers are
     treated as "true" values and strictly negative integers are treated as
     invlaid  values.  Note  that this  only  affect arrays  of int's  (not
     long's  nor short's nor  char's).  The  default is  to save  arrays of
     int's as array of 32 bits integers.

     The returned value is FH.

   SEE ALSO: fits, fits_new_bintable, fits_read_bintable. */
{
  /* Minimal checking. */
  if (fits_get(fh, "XTENSION") != "BINTABLE")
    error, "current HDU is not a FITS BINTABLE";
  if (structof(ptr) == pointer) {
    ptr = ptr; /* force private copy */
  } else if (is_array(ptr)) {
    /* will save as binary table with a single field */
    ptr = &ptr;
  } else {
    error, "expecting array or pointer to save in BINTABLE";
  }

  /* Guess the format. */
  tfields = numberof(ptr);
  tform = array(string, tfields);
  mult = size = array(long, tfields);
  nrows = -1;
  for (i=1 ; i<=tfields ; ++i) {
    local a; eq_nocopy, a, *ptr(i);
    if (! is_array(a)) error, "unexpected non-array field for BINTABLE";
    dims = dimsof(a);
    ndims = dims(1);
    if (ndims != 2 && ndims != 1)
      error, "only 1 or 2-dimensional arrays can be a field of a BINTABLE";
    if (i == 1) nrows = dims(2);
    else if (dims(2) != nrows)
      error, "all fields of a BINTABLE must have the same number of rows";
    type = structof(a);
    ncols = (ndims == 2 ? dims(3) : 1);                      
    if (type == double) {
      t = 'D';
      size(i) = 8;
    } else if (type == long) {
      t = 'J';
      size(i) = 4;
    } else if (type == char) {
      t = 'B';
      size(i) = 1;
    } else if (type == complex) {
      t = 'M';
      size(i) = 16;
    } else if (type == int) {
      if (logical) {
        t = 'L';
        size(i) = 1;
        tmp = array('F', dims); /* array of "false" values */
        if (logical == 2) {
          /* Treats strictly negative values as "bad" values and strictly
             positive values as "true" values. */
          if (is_array((j = where(a < 0)))) tmp(j) = '\0';
          if (is_array((j = where(a > 0)))) tmp(j) = 'T';
        } else {
          /* Treats non-zero values as "true" values. */
          if (is_array((j = where(a)))) tmp(j) = 'T';
        }
        ptr(i) = &tmp; /* only affect local (private) copy */
      } else {
        t = 'J';
        size(i) = 4;
      }
    } else if (type == float) {
      t = 'E';
      size(i) = 4;
    } else if (type == short) {
      t = 'I';
      size(i) = 2;
    } else if (type == string) {
      t = 'A';
      size(i) = 1;
      if (ncols != 1) error, "only string vectors implemented in BINTABLE";
      ncols = max((len = strlen(a)));
      tmp = array(char, nrows, ncols);
      for (k=1 ; k<=nrows ; ++k) {
        if ((l = len(k))) tmp(k, 1:l) = (*pointer(a(k)))(1:l);
      }
      ptr(i) = &tmp; /* only affect local (private) copy */
    } else if (type == pointer) {
      error, "pointer fields not yet implemented in BINTABLE";
    } else {
      error, "unsupported data type in BINTABLE";
    }
    mult(i) = ncols;
    tform(i) = swrite(format="%d%c", ncols, t);
  }

  /* Update header information then write header. */
  size *= mult; /* number of bytes per rows for each field */
  nbytes = sum(size);
  pcount = _fits_bintable_header(fh, nbytes, nrows, tfields);
  for (i=1 ; i<=tfields ; ++i) {
    fits_set, fh, swrite(format="TFORM%d", i), tform(i),
      "format of " + fits_nth(i) + " field";
  }
  fits_write_header, fh;

  /* Write data. */
  local offset; eq_nocopy, offset, _car(fh, 3);
  stream = _car(fh, 4);
  address = offset(3);
  if (tfields == 1) {
    /* Fast write in this case. */
    _write, stream, address, *ptr(1);
    address += nbytes*nrows;
  } else {
    /* Write data, one row at a time, one field at a time. This is really
       inefficient, but I do not see any other way to do that (using some
       equivalent structure in Yorick defined "on-the-fly" would be very
       complicated and cannot solve for all the cases). */
    for (j=1 ; j<=nrows ; ++j) {
      for (i=1 ; i<=tfields ; ++i) {
        _write, stream, address, (*ptr(i))(j,);
        address += size(i);
      }
    }
  }

  /* Pad with null's to have an integer number of FITS blocks. */
  if (pcount) {
    _write, stream, address, array(char, pcount);
    address += pcount;
  }

  /* Update FITS handle. */
  offset(4) = address;
  return fh;
}

func fits_read_bintable(fh, pack=, select=, raw_string=, raw_logical=,
                        bad=, trim=)
/* DOCUMENT fits_read_bintable(fh)
     Reads a binary table in current  HDU of FITS handle FH and returns the
     fields of  the table as  a pointer array  (i-th field of the  table is
     pointed  by  i-th  pointer  element).   Empty fields  and  fields  for
     unsupported data  types (bit array  and array descriptor) result  in a
     null pointer (&[]).  The geometry  of the arrays pointed by the result
     will be  NROWS-by-NCOLS(i) where  NROWS is the  number of rows  in the
     table and NCOLS(i) is the repeat  count of the i-th field in the table
     (see fits_write_bintable).  If NCOLS(i)  = 1, the i-th pointer element
     is the address of a NROWS vector, i.e. not a NROWS-by-1 array.

     Keyword SELECT  can be  used to retain  only some fields  (or re-order
     them) of the  table.  For instance, use SELECT=[2,5,3]  to return only
     2nd, 5th and 3rd fields (in  that order) of the table.  The fields can
     also be selected by their names, e.g. SELECT=["flux","distance"] (note
     that trailing spaces and case is not significant for the field names).

     If keyword  PACK is  true, fits_pack_bintable (which  see) is  used to
     pack the  columns of  the binary table  into a single  array (possibly
     after selection/re-ordering by SELECT).

     If keyword TRIM is true,  then trailing spaces get removed from string
     fields (this has no effect if RAW_STRING is true).

     If keyword RAW_STRING is true,  fields made of char's ('A' format) are
     returned as  arrays of char's.  The  default is to  convert 'A' format
     fields into 1-by-NROWS array of strings.

     If  keyword  RAW_LOGICAL is  true,  logical  fields  ('L' format)  are
     returned as  arrays of char's.  The  default is to  convert 'L' format
     fields  into array of  int's as  follows: 'T'  -> 1  (true), 'F'  -> 0
     (false), and any other character ->  -1 (bad).  The 'bad' value can be
     set by keyword BAD (default is -1).

   SEE ALSO: fits, fits_write_bintable, fits_pack_bintable. */
{
  /* Minimal checking. */
  if (fits_get(fh, "XTENSION") != "BINTABLE" || fits_get_naxis(fh) != 2) {
    error, "current HDU is not a valid FITS BINTABLE";
  }
  nbytes = fits_get(fh, "NAXIS1");
  nrows = fits_get(fh, "NAXIS2");
  tfields = fits_get(fh, "TFIELDS");
  if (nbytes <= 0 || nrows <= 0) return;

  /* May-be we just want some fields given their names. */
  if (structof(select) == string) {
    ttype = array(string, tfields);
    for (i=1 ; i<=tfields ; ++i) {
      s = fits_get(fh, swrite(format="TTYPE%d", i));
      if (structof(s) == string) {
        s = fits_trim(s); // FIXME: not needed (see fits_parse)
        if (strlen(s)) ttype(i) = fits_tolower(s);
      }
    }
    n = numberof(select);
    tmp = array(long, dimsof(select)); // result will have same geometry
    for (i=1 ; i<=n ; ++i) {
      j = where(fits_tolower(fits_trim(select(i))) == ttype);
      if (numberof(j) != 1) {
        if (is_array(j)) error, "more than one field match \""+select(i)+"\"";
        error, "no field matches \""+select(i)+"\"";
      }
      tmp(i) = j(1);
    }
    select = tmp;
    tmp = ttype = []; // free some memory
  }

  /* Extract formats. */
  ptr = array(pointer, tfields);
  if (nrows > 1) row = array(pointer, tfields);
  is_string = array(int, tfields);
  is_logical = array(int, tfields);
  is_complex = array(int, tfields);
  is_not_byte = array(int, tfields);
  size = array(long, tfields);
  mult = array(long, tfields);
  s = nil = string(0);
  m = 0;
  warn_X = warn_P = 1;
  for (i=1 ; i<=tfields ; ++i) {
    tform = fits_get(fh, (key = swrite(format="TFORM%d", i)));
    if (structof(tform) != string)
      error, ((is_void(tform) ? "missing" : "unexpected data type for")
              + " FITS card \""+key+"\"");
    if (sread(format="%d%1s%s", tform, m, s, nil) != 2) {
      if (sread(format="%1s%s", tform, s, nil) == 1) m = 1;
      else error, "bad format string in FITS card \""+key+"\"";
    }
    c = (*pointer(s))(1);
    if (c == 'L') {
      type = char;
      size(i) = (mult(i) = m);
      is_logical(i) = 1n;
    } else if (c == 'B') {
      type = char;
      size(i) = (mult(i) = m);
    } else if (c == 'I') {
      type = short;
      size(i) = 2*(mult(i) = m);
    } else if (c == 'J') {
      type = long;
      size(i) = 4*(mult(i) = m);
    } else if (c == 'E') {
      type = float;
      size(i) = 4*(mult(i) = m);
    } else if (c == 'D') {
      type = double;
      size(i) = 8*(mult(i) = m);
    } else if (c == 'C') {
      type = float;
      size(i) = 4*(mult(i) = 2*m);
      is_complex(i) = 1n;
    } else if (c == 'M') {
      type = complex;
      size(i) = 16*(mult(i) = m);
    } else if (c == 'A') {
      type = char;
      size(i) = (mult(i) = m);
      is_string(i) = 1n;
    } else if (c == 'X') {
      /* bit array */
      size(i) = (m + 7)/8; /* round up to a number of 8-bit bytes */
      mult(i) = 0;  /* skip this field */
      if (warn_X) {
        _fits_warn, "bit array in FITS binary table not yet implemented";
        warn_X = 0;
      }
    } else if (c == 'P') {
      /* array descriptor */
      size(i) = 8*m;
      mult(i) = 0;  /* skip this field */
      if (warn_P) {
        _fits_warn, "pointer array in FITS binary table not yet implemented";
        warn_P = 0;
      }
    } else {
      error, "unknown format \""+tform+"\" in FITS binary table";
    }
    ncols = mult(i);
    if (ncols) {
      ptr(i) = &(ncols == 1 ? array(type, nrows) : array(type, nrows, ncols));
      if (nrows > 1) row(i) = &array(type, ncols);
      is_not_byte(i) = (type != char);
    }
  }

  /* Read data. */
  local a, offset;
  eq_nocopy, offset, _car(fh, 3);
  address = offset(3);
  stream = _car(fh, 4);
  if ((row_pad = (nbytes - sum(size))) < 0)
    error, "inconsistent NAXIS1 in FITS binary table";
  if (nrows == 1 || (row_pad == 0 && tfields == 1)) {
    /* Faster read: avoid unnecessary copies if NROWS=1, or read the whole
       table can in a single call to _read if TFIELDS=1 and there are no
       padding bytes. */
    for (i=1 ; i<=tfields ; ++i) {
      if (mult(i)) {
        eq_nocopy, a, *ptr(i);
        if (is_not_byte(i)) _read, stream, address, a;
        else if (_read(stream, address, a) != size(i)) error, "short file";
      }
      address += size(i);
    }
  } else {
    /* Multiple rows _and_ multiple fields: must read one row at a time,
       one field at a time. */
    for (k=1 ; k<=nrows ; ++k) {
      for (i=1 ; i<=tfields ; ++i) {
        if (mult(i)) {
          eq_nocopy, a, *row(i);
          if (is_not_byte(i)) _read, stream, address, a;
          else if (_read(stream, address, a) != size(i))
            error, "short file";
          (*ptr(i))(k,) = a;
        }
        address += size(i);
      }
      address += row_pad;
    }
  }

  /* Fix single precision complex array. */
  if ((n = numberof((i = where(is_complex)))) > 0) {
    for (k=1 ; k<=n ; ++k) {
      j = i(k);
      eq_nocopy, a, *ptr(j);
      a = a(,1::2) + 1i*a(,2::2);
      ptr(j) = &(mult(j) == 2 ? a(,1) : a);
    }
  }

  /* Fix logical array: 'T' -> 1 (true), 'F' -> 0 (false), and any other
     character -> -1 (bad). */
  if (! raw_logical && (n = numberof((i = where(is_logical)))) > 0) {
    if (is_void(bad)) bad = -1;
    for (k=1 ; k<=n ; ++k) {
      j = i(k);
      r = (*ptr(j) == 'T');
      if (is_array((l = where(! ((*ptr(j) == 'F') | r))))) r(l) = bad;
      ptr(j) = &r;
    }
  }

  /* Fix string array. */
  if (! raw_string && (n = numberof((i = where(is_string)))) > 0) {
    local a;
    for (k=1 ; k<=n ; ++k) {
      j = i(k);
      eq_nocopy, a, *ptr(j);
      tmp = array(string, nrows);
      for (l=1 ; l<=nrows ; ++l) {
        if ((c = a(l,))(1)) {
          if (trim) {
            r = numberof(c);
            t = 0;
            while (++t <= r && c(t))
              ;
            while (--t && c(t) == ' ')
              ;
            if (t >= 1) tmp(l) = string(&c(1:t));
          } else {
            tmp(l) = string(&c);
          }
        }
      }
      ptr(j) = &tmp;
    }
  }

  if (! is_void(select)) ptr = ptr(select);
  return (pack ? fits_pack_bintable(ptr) : ptr);
}

func fits_pack_bintable(ptr)
/* DOCUMENT fits_pack_bintable(ptr)
       -or- fits_pack_bintable(ptr(list))
     Packs binary  table PTR  into a  single array; PTR  must be  a pointer
     array (e.g. as the one returned by fits_read_bintable which see).  The
     argument can be PTR(LIST) to select or re-order some fields: LIST is a
     vector  of indices of  selected and  re-ordered fields.   The returned
     array  is NROWS-by-NCOLS  where NROWS  is the  first dimension  of all
     fields (which  must be the  same) and NCOLS  is the sum of  the second
     dimension of all fields.
     
   SEE ALSO: fits_read_bintable. */
{  
  if (structof(ptr) != pointer) error, "expecting array of pointer argument";
  n = numberof(ptr);
  begin = array(long, n + 1);
  end = array(long, n);
  begin(1) = 1;
  ncols = 0;
  type = [];
  for (i=1 ; i<=n ; ++i) {
    if ((s = structof(*ptr(i))) != char && s != short && s != int &&
        s != long && s!=float && s!=double && s != string) {
      error, "bad data type in table column";
    }
    dims = dimsof(*ptr(i));
    ndims = dims(1);
    if (ndims == 1) {
      ++ncols;
    } else if (ndims == 2) {
      ncols += dims(3);
    } else {
      error, "unexpected dimension list in table column";
    }
    end(i) = ncols - 1;
    begin(i+1) = ncols;
    if (i == 1) {
      nrows = dims(2);
      type = s;
    } else {
      if (dims(2) != nrows) error, "bad number of rows in table column";
      if (s != type) {
        if (s == string || type == string)
          error, "mixing of text and numerical data";
        type = structof(type(0) + s(0));
      }
    }
  }

  /* Pack selected columns. */
  arr = array(type, nrows, ncols);
  for (i=1 ; i<=n ; ++i) {
    arr(,begin(i):end(i)) = *ptr(i);
  }
  return arr;
}

func _fits_bintable_header(fh, nbytes, nrows, tfields)
/* DOCUMENT _fits_bintable_header(fh, nbytes, nrows, tfields)
     Set/update header  information in  FITS handle FH  for a  binary table
     extension.  NBYTES is the number of  bytes per row of the table, NROWS
     is  the number  of table  rows  and TFIELDS  is the  number of  fields
     (columns in  the table).  FITS  card "XTENSION" with  value "BINTABLE"
     must already exists  in the header (this is  not checked).  FITS cards
     "BITPIX",  "NAXIS",   "NAXIS1",  "NAXIS2",  "PCOUNT",   "GCOUNT",  and
     "TFIELDS" get created/updated by this routine.  The value of PCOUNT is
     computed by the routine and returned to the caller.

   SEE ALSO: fits, fits_new_bintable, fits_write_bintable. */
{
  block = 2880;
  pcount = ((nbytes*nrows + block - 1)/block)*block - nbytes*nrows;
  fits_set, fh, "BITPIX", 8, "data contains array of bytes";
  fits_set, fh, "NAXIS", 2, "two-dimensional binary table";
  fits_set, fh, "NAXIS1", nbytes, "number of 8-bit bytes in a table row";
  fits_set, fh, "NAXIS2", nrows, "number of rows in the table";
  fits_set, fh, "PCOUNT", pcount,
    "total number of bytes is PCOUNT + NAXIS1*NAXIS2";
  fits_set, fh, "GCOUNT", 1, "always 1 for binary table extensions";
  fits_set, fh, "TFIELDS", tfields, "number of fields in each row";
  return pcount;
}

func fits_read_bintable_as_hashtable(fh, h, format=,
                                     select=, raw_string=, raw_logical=, bad=)
/* DOCUMENT fits_read_bintable_as_hashtable(fh)
       -or- fits_read_bintable_as_hashtable(fh, h)

     Read  binary table  in current  HDU (see  fits_read_bintable)  of FITS
     handle FH  and make it into a  hash table.  If optional  argument H is
     given, it  must be  an existing  hash table to  be augmented  with the
     contents of the binary table.  The (augmented) hash table is returned.
     This function can only be used with the hash table extension.

     The  members of  the  hash table  get  named after  the  value of  the
     'TTYPEn' card  converted to lowercase  (where n is the  field number).
     For missing  'TTYPEn' cards,  the value of  keyword FORMAT is  used to
     define the member name  as swrite(format=FORMAT,n).  The default value
     for FORMAT is "_%d".  If  FORMAT is specified, it must contain exactly
     one directive to write an  integer and no other format directives.  If
     a card 'TUNITn' exists, its  value is stored into member with "_units"
     appended to the corresponding field name.
     
     Keywords SELECT, RAW_STRING, RAW_LOGICAL and BAD have the same meaning
     as in fits_read_bintable.
     
   SEE ALSO: fits_read_bintable, swrite, h_new. */
{
  ptr = fits_read_bintable(fh, select=select, bad=bad,
                           raw_string=raw_string, raw_logical=raw_logical);
  n = numberof(ptr);
  augment = is_hash(h);
  if (! augment) {
    if (is_void(h)) h = h_new();
    else error, "expecting a hash table";
  }
  if (is_void(format)) format = "_%d";
  for (i=1 ; i<=n ; ++i) {
    name = fits_get(fh, swrite(format="TTYPE%d", i));
    if (structof(name) == string && strlen(name)) {
      name = fits_tolower(name);
    } else {
      name = swrite(format=format, i);
    }
    h_set, h, name, *ptr(i);
    units = fits_get(fh, swrite(format="TUNIT%d", i));
    name_units = name + "_units";
    if (structof(units) == string && strlen(units)) {
      h_set, h, name_units, units;
    } else if (augment) {
      h_pop, h, name_units;
    }
  }
  return h;
}

/*---------------------------------------------------------------------------*/
/* MISCELLANEOUS */

/* Note: The following fits_toupper and fits_tolower routines are ~2 times
   faster than their ancestors in "string.i". */

local _fits_tolower;
local _fits_toupper;
/* DOCUMENT _fits_tolower
            _fits_toupper
     Private arrays to convert char to upper/lowercase letters.

   SEE ALSO: fits, fits_tolower, fits_toupper. */
(_fits_tolower=char(indgen(0:255)))(1+'A':1+'Z')=_fits_tolower(1+'a':1+'z');
(_fits_toupper=char(indgen(0:255)))(1+'a':1+'z')=_fits_toupper(1+'A':1+'Z');

func fits_tolower(s)
{ extern _fits_tolower; n = numberof((r = array(string, dimsof(s))));
  for (i=1 ; i<=n ; ++i) r(i) = string(&_fits_tolower(1 + *pointer(s(i))));
  return r; }
func fits_toupper(s)
{ extern _fits_toupper; n = numberof((r = array(string, dimsof(s))));
  for (i=1 ; i<=n ; ++i) r(i) = string(&_fits_toupper(1 + *pointer(s(i))));
  return r; }
/* DOCUMENT fits_tolower(s)
       -or- fits_toupper(s)
     Converts a string or an array of strings S to lower/upper case letters.

   SEE ALSO: fits, fits_trim. */

func fits_trim(s)
/* DOCUMENT fits_trim(s)
     Removes trailing  spaces (character 0x20) from scalar  string S (note:
     trailing spaces are not significant in FITS).

   SEE ALSO: fits, fits_tolower, fits_toupper. */
{
  if (! (i = numberof((c = *pointer(s))))) return string(0);
  while (--i) { if (c(i) != ' ') return string(&c(1:i)); }
  return "";
}

func fits_map(op, src)
/* DOCUMENT fits_map(op, src)
     Map scalar function OP onto array argument SRC to mimics element-wise
     unary operation.

   SEE ALSO: fits. */
{
  if (! (n = numberof(src))) return;
  /* use structof to avoid unecessary string duplication for string result */
  dst = array(structof((dst1 = op(src(1)))), dimsof(src));
  dst(1) = dst1;
  for (i=2 ; i<=n ; ++i) dst(i) = op(src(i));
  return dst;
}

func fits_is_scalar(x) { return (is_array(x) && ! dimsof(x)(1)); }
/* DOCUMENT fits_is_scalar(x)
     Returns true if X is a scalar.

   SEE ALSO: fits_is_integer_scalar, fits_is_real_scalar,
             fits_is_string_scalar. */

func fits_is_integer(x)
/* DOCUMENT fits_is_integer(x)
     Returns true if array X is of integer type.

   SEE ALSO: fits_is_scalar. */
{ return ((s=structof(x)) == long || s == int || s == char || s == short); }

func fits_is_integer_scalar(x)
/* DOCUMENT fits_is_integer_scalar(x)
     Returns true if array X is a scalar of integer type.

   SEE ALSO: fits_is_real_scalar, fits_is_scalar, fits_is_string_scalar. */
{
  return (((s=structof(x)) == long || s == int || s == char || s == short) &&
          ! dimsof(x)(1));
}

func fits_is_real_scalar(x)
/* DOCUMENT fits_is_real_scalar(x)
     Returns true if array X if of real type (i.e. double or float).

   SEE ALSO: fits_is_integer_scalar, fits_is_scalar, fits_is_string_scalar. */
{ return (((s=structof(x)) == double || s == float) && ! dimsof(x)(1)); }

func fits_is_string_scalar(x)
/* DOCUMENT fits_is_string_scalar(x)
     Returns true if array X is a scalar of string type.

   SEE ALSO: fits_is_integer_scalar, fits_is_real_scalar, fits_is_scalar. */
{ return (structof(x) == string && ! dimsof(x)(1)); }

func fits_filename(stream)
/* DOCUMENT fits_filename(fh)
     Return path name  of file associated with FITS handle  FH (in fact the
     argument may also be any Yorick open stream).

   SEE ALSO: fits. */
{
  /* Get stream from FITS handle. */
  if ((id = typeof(stream)) == "list") {
    if (_len(stream) != 4) error, "bad FITS handle";
    id = typeof((stream = _car(stream, 4)));
  }

  /* Check input and get description of stream by the print() command. */
  if ((id = typeof(stream)) == "stream") { id = 1; s = print(stream); }
  else if (id == "text_stream")          { id = 2; s = print(stream)(2:); }
  else error, "unexpected non-stream argument";

  /* Join backslash terminated lines from print() result (another
     possibility would be to change the line length with `print_format' but
     there is no way to restore the previous line_lenght unles we building
     a wrapper around original `print_format' routine and make a
     substitution). */
  join = (strpart(s, 0:0) == "\\");
  if (anyof(join)) {
    r = array(string, (ns= numberof(s)) - sum(join) + join(0));
    i = j= 0;
    while (i<ns) {
      w = s(++i);
      while (join(i)) {
        w = strpart(w, :-1);
        if (++i>ns) break;
        w += s(i);
      }
      r(++j) = w;
    }
    s = r;
    w = r = [];
  }

  /* Recover the full path of the stream file from the joined lines. */
  if (id == 1) {
    /* Binary stream. */
    if (numberof(s)==2) {
      w1= w2= string(0);
      if (sread(s(1), format="%[^:]", w1)==1 &&
          sread(s(2), format="%[^/]", w2)==1) {
        return strpart(s(2), strlen(w2)+1:0) + strpart(s(1), strlen(w1)+3:0);
      }
    }
    error, "unexpected binary stream descriptor";
  } else {
    /* Text stream. */
    if (numberof(s) == 1) {
      w = string(0);
      if (sread(s(1), format="%[^/]", w)==1) {
        return strpart(s(1), strlen(w)+1:0);
      }
    }
    error, "unexpected text stream descriptor";
  }
}

func fits_check_bitpix(bitpix)
/* DOCUMENT fits_check_bitpix(bitpix)
     Test if FITS bits-per-pixel value BITPIX is valid.

   SEE ALSO: fits, fits_bitpix_of, fits_bitpix_type, fits_bitpix_info. */
{
  return ((bitpix>0 && (bitpix==8 || bitpix==16 || bitpix==32)) ||
          bitpix==-32 || bitpix==-64);
}

func fits_bitpix_info(bitpix)
/* DOCUMENT fits_bitpix_info(bitpix)
     Return string information about FITS bits-per-pixel value.

   SEE ALSO: fits, fits_bitpix_of, fits_bitpix_type, fits_check_bitpix. */
{
  if (bitpix ==   8) return "8-bit twos complement binary unsigned integer";
  if (bitpix ==  16) return "16-bit twos complement binary integer";
  if (bitpix ==  32) return "32-bit twos complement binary integer";
  if (bitpix == -32) return "IEEE single precision floating point";
  if (bitpix == -64) return "IEEE double precision floating point";
  error, "invalid BITPIX value";
}

func fits_bitpix_type(bitpix, native=)
/* DOCUMENT fits_bitpix_type(bitpix)
       -or- fits_bitpix_type(bitpix, native=1)
     Returns Yorick data type given by FITS bits-per-pixel value BITPIX.
     If keyword NATIVE is true, return the native data type matching BITPIX.

   SEE ALSO: fits, fits_bitpix_of, fits_bitpix_info, fits_check_bitpix. */
{
  if (native) {
    /* Figure out native type matching BITPIX. */
    if (bitpix > 0) {
      if (bitpix ==  8*sizeof(long))   return long;
      if (bitpix ==  8*sizeof(int))    return int;
      if (bitpix ==  8*sizeof(short))  return short;
      if (bitpix ==  8*sizeof(char))   return char;
    } else {
      if (bitpix == -8*sizeof(double)) return double;
      if (bitpix == -8*sizeof(float))  return float;
    }
  } else {
    /* Assume XDR type. */
    if (bitpix ==   8) return char;
    if (bitpix ==  16) return short;
    if (bitpix ==  32) return long;
    if (bitpix == -32) return float;
    if (bitpix == -64) return double;
  }
  error, "invalid/unsupported BITPIX value";
}

func fits_bitpix_of(x, native=)
/* DOCUMENT fits_bitpix_of(x)
       -or- fits_bitpix_of(x, native=1)
     Return FITS bits-per-pixel value BITPIX for binary data X which can be
     an array or a data  type (structure definition).  If keyword NATIVE is
     true, the routine assumes that  binary data will be read/write to/from
     FITS file using native machine data representation.  The default is to
     conform to FITS standard and to  assume that XDR binary format will be
     used in FITS file.

   SEE ALSO: fits, fits_bitpix_type, fits_check_bitpix. */
{
  if (is_array(x)) {
    x = structof(x);
  } else if (typeof(x) != "struct_definition") {
    error, "expecting array or data type argument";
  }
  if (native) {
    /* Compute BITPIX. */
    bpb = 8; /* assume 8 bits per byte */
    if (x==char || x==short || x==int || x==long) {
      bitpix = bpb*sizeof(x);
      if (bitpix == 8 || bitpix == 16 || bitpix == 32) return bitpix;
    } else if (x == float || x == double) {
      bitpix = -bpb*sizeof(x);
      if (bitpix == -32 || bitpix == -64) return bitpix;
    }
  } else {
    /* Assume data will be read/written as XDR. */
    if (x == char) return 8;
    if (x == short) return 16;
    if (x == int || x == long) return 32;
    if (x == float) return -32;
    if (x == double) return -64;
  }
  error, "unsupported data type \""+nameof(x)+"\"";
}

/*---------------------------------------------------------------------------*/
/* CARDS AND KEYS */

local _fits_parse_comment;
func fits_parse(card, id, safe=)
/* DOCUMENT fits_parse(card);
       -or- fits_parse(card, id);
     Return value  of a single  FITS card (CARD  is a scalar  string).  The
     type of the scalar result is as follow:
        - string for a string or a commentary FITS card
        - char ('T' for true or 'F' for false) for a logical FITS card
        - long for an integer FITS card
        - double for a real FITS card
        - complex for a complex FITS card

     In order to save a call to  fits_id, if ID is non-nil it is assumed to
     be the numerical identifier of the card, i.e. fits_id(CARD).

     The   comment  part   of   CARD  is   stored   into  external   symbol
     _fits_parse_comment which is a string (possibly nil) for a valued card
     and void (i.e. []) for a commentary card.

     If the  SAFE keyword is true,  the routine returns an  empty result in
     case of error.

   SEE ALSO: fits, fits_get, fits_id. */
{
  extern _fits_parse_comment;
  extern _fits_id_comment, _fits_id_history;

  if (is_void(id)) id = fits_id(card);
  tail = strpart(card, 9:);

  /* Deal with commentary card. */
  if (id == 0.0 || id == _fits_id_comment || id == _fits_id_history) {
    _fits_parse_comment = [];
    return tail;
  }

  /* Use first non-space character after '=' for faster guess (I don't
     want to be too strict there: FITS standard requires that bytes
     9-10 be "= " for a valued-card, but the following sread format
     succeeds if bytes 9-80 is a "=" followed by any number of spaces
     and at least a non-space character). */
  r = s = _fits_parse_comment = string(0);
  if ((n = sread(tail, format="%1[=]%1s", r, s)) != 2) {
    if (n == 0) {
      /* Must be END card. */
      if (id == _fits_id_end) {
        _fits_parse_comment = [];
        return;
      }
    } else /* n = 1 */ {
      /* Undefined keyword. */
      return;
    }
  } else if (strmatch("0123456789+-.", s)) {
    /* Numerical value...
       ... try integer value: */
    re = 0;
    n = sread(tail, format="=%d%1s %[^\a]", re, s, _fits_parse_comment);
    if (n==1 || (n>1 && s=="/")) return re;

    /* ... try real value: */
    re = 0.0;
    n = sread(tail, format="=%f%1s %[^\a]", re, s, _fits_parse_comment);
    if (n==1 || (n>1 && s=="/")) return re;

    /* ... try complex value: */
    im = 0.0;
    n = sread(tail, format="=%f%f%1s %[^\a]", re, im, s, _fits_parse_comment);
    if (n==2 || (n>2 && s=="/")) return re + 1i*im;

  } else if (s=="T" || s=="F") {
    /* Logical value. */
    value = (s == "T" ? 'T' : 'F');
    n = sread(tail, format="= "+s+"%1s %[^\a]", s, _fits_parse_comment);
    if (n==0 || (n>0 && s=="/")) return value;

  } else if (s=="'" && sread(tail, format="= '%[^\a]", s)) {
    /* String value. */
    q = p1 = p2 = string(0);
    value = "";
    do {
      if (sread(s, format="%[^']%[']%[^\a]", p1, q, p2)) value += p1;
      else if (! sread(s, format="%[']%[^\a]", q, p2)) break;
      if ((n = strlen(q)) > 1) value += strpart(q, :n/2);
    } while ((s=p2) && !(n%2));
    if (! sread(s, format="%1s %[^\a]", q, _fits_parse_comment) || q=="/") {
      /* discard trailing spaces which are not significant in FITS */
      i = numberof((c = *pointer(value)));
      while (--i) { if (c(i) != ' ') return string(&c(1:i)); }
      return "";
    }
  } else if (s == "/") {
    /* Undefined keyword with comment. */
    sread, tail, format="= / %[^\a]", _fits_parse_comment;
    return;
  }

  if (! safe) error, "syntax error in FITS card \""+strpart(card, 1:8)+"\"";
}

func fits_get(fh, pattern, &comment, default=, promote=)
/* DOCUMENT fits_get(fh, pattern, comment)
     Get  (array  of)  value(s)   for  FITS  cards  matching  PATTERN  (see
     fits_match) in current header of FITS handle FH.  If present, argument
     COMMENT is  an output symbol  where the corresponding comment  part of
     selected card(s)  will be stored.   In order to avoid  namespace clash
     due to Yorick's  scoping rules, COMMENT should be  declared as a local
     symbol in the calling function, e.g.:
       local comment;
       value = fits_get(fh, pattern, comment);

     If no  cards match PATTERN, the  value of keyword  DEFAULT is returned
     and COMMENT is set to the null string.

     If multiple  cards match PATTERN, they  must have the  same value type
     unless keyword PROMOTE is true, in which case the routine promotes all
     card values to a suitable "highest" type.

     Request fo commentary cards  (i.e. PATTERN is "HISTORY", "COMMENT", or
     "") may returns several cards.

   SEE ALSO: fits, fits_match, fits_parse. */
{
  local _fits_parse_comment;
  extern _fits_match_id, _fits_id_history;
  i = where(fits_match(fh, pattern));
  if (! is_array(i)) {
    comment = string(0);
    return default;
  }
  card = _car(fh,1)(i);

  value = fits_parse(card(1), _fits_match_id);
  if ((number = numberof(card)) == 1) {
    comment = _fits_parse_comment;
    return value;
  }
  type = structof(value);
  result = array(value, number);
  if (is_void(_fits_parse_comment)) {
    comment = [];
  } else {
    comment = array(string, number);
    comment(1) = _fits_parse_comment;
  }
  for (i=2 ; i<=number ; ++i) {
    value = fits_parse(card(i), _fits_match_id);
    if ((new_type = structof(value)) != type) {
      if (! promote) error, "multiple cards with different data types";
      if (type == string || new_type == string)
        error, "cannot mix string cards with other ones";
      if (type == char || new_type == char)
        error, "cannot mix logical cards with other ones";
      new_type = structof(type(0) + new_type(0));
      if (type != new_type) {
        type = new_type;
        result = type(result);
      }
    }
    result(i) = value;
    if (is_array(comment)) comment(i) = _fits_parse_comment;
  }
  return result;
}

local _fits_match_id;
func fits_match(fh, pattern)
/* DOCUMENT fits_match(fh, pattern)
     Return array of int's which are non-zero where FITS card names in FITS
     handle  FH  match PATTERN.   PATTERN  must be  a  scalar  string or  a
     numerical identifier.  As a  special case, if  PATTERN is of  the form
     "KEYWORD#" (i.e.  last character of  PATTERN is a '#'), then any human
     readable integer will match the '#', e.g. "NAXIS#" will match "NAXIS3"
     and "NAXIS11" but not "NAXIS" nor "QNAXIS4.

     Global/extern  variable  _fits_match_id  is  set  with  the  numerical
     identifier of PATTERN (without last '#' if any).

   SEE ALSO: fits, fits_get_cards, fits_rehash. */
{
  extern _fits_multiplier, _fits_match_id;
  if (! is_array(_car(fh,1))) return;
  if ((s = structof(pattern)) == double) {
    return (_car(fh,2) == (_fits_match_id = pattern));
  } else if (s != string) {
    error, "PATTERN must be a scalar string or a numerical identifier";
  }
  if (strpart(pattern, 0:0) != "#") {
    return (_car(fh,2) == (_fits_match_id = fits_id(pattern)));
  }
  if ((len = strlen(pattern)) > 7) {
    _fits_match_id = -1.0; // means something wrong
    return array(0n, numberof(_car(fh,2)));
  }
  if (len <= 1) {
    _fits_match_id = 0.0;
    ok = array(1n, numberof(_car(fh,2)));
  } else {
    _fits_match_id = fits_id(strpart(pattern, 1:-1));
    ok = (_car(fh,2) % _fits_multiplier(len)) == _fits_match_id;
  }
  if (is_array((i = where(ok)))) {
    u = v = string(0);
    n = numberof((w = strpart(_car(fh,1)(i), len:8)));
    for (j=1 ; j<=n ; ++j) {
      if (sread(format="%[0-9]%s", w(j), u, v) != 1) ok(i(j)) = 0n;
    }
  }
  return ok;
}

func fits_get_cards(fh, pattern)
/* DOCUMENT fits_get_cards(fh, pattern);
     Return cards from  FITS handle FH which match  PATTERN (see fits_match
     for the syntax of PATTERN).

   SEE ALSO: fits, fits_match. */
{
  local _fits_match_id;
  i = where(fits_match(fh, pattern));
  if (is_array(i)) return _car(fh,1)(i);
}

func fits_delete(fh, pattern)
/* DOCUMENT fits_delete, fh, pattern;
     Delete all cards  matching PATTERN from current header  of FITS handle
     FH (see fits_match for the syntax of PATTERN).

   SEE ALSO: fits, fits_match. */
{
  local _fits_match_id;
  i = where(! fits_match(fh, pattern));
  if (is_array(i) && numberof(i) < numberof(_car(fh,1))) {
    _car,fh,1,_car(fh,1)(i);
    _car,fh,2,_car(fh,2)(i);
  }
}

func fits_ids(cards) { return fits_map(fits_id, cards); }
func fits_id(card)
/* DOCUMENT fits_id(card)
       -or- fits_ids(cards)
     Convert  FITS  card(s) or  FITS  card  name(s)  into unique  numerical
     identifier.  CARD is a scalar string and CARDS (with an S) is an array
     of string(s) (including a  scalar).  Only the keyword part (characters
     1:8) of CARD(S) is relevant; cards shorter than 8 characters yield the
     same identifier as if they were padded (right filled) with spaces.  In
     other words, all the values  returned by the following expressions are
     identical:
       fits_id("SIMPLE = T / conforming FITS file");
       fits_id("SIMPLE ");
       fits_id("SIMPLE");

   SEE ALSO: fits, fits_key, fits_rehash. */
{
  extern _fits_digitize, _fits_multiplier;
  if ((len = numberof((c = *pointer(card)))) <= 1) return 0.0;
  len = min(8, len - 1);
  digit = _fits_digitize(1 + c(1:len));
  if (min(digit) < 0  || min((!digit)(dif)) < 0) error, _fits_bad_keyword(c);
  return sum(_fits_multiplier(1:len)*digit);
}

func _fits_bad_keyword(c)
/* DOCUMENT _fits_bad_keyword(c)
     Returns error message due to invalid FITS keyword.  C is an array of
     characters that compose the bad FITS keyword.

   SEE ALSO: fits_id, fits_read_header. */
{
  if ((n = min(8, numberof(c)))) {
    digit = _fits_digitize(1 + c(1:n));
    do {
      if (digit(n)) {
        key = string(&c(1:n));
        if (min(digit) < 0)
          return ("bad character(s) in FITS keyword \"" +
                  key + "\" (see option ALLOW in fits_init)");
        if (min((!digit)(dif)) < 0)
          return ("leading/embedded blanks forbidden in FITS keyword \"" +
                  key + "\"");
      }
    } while (--n > 0); /* remove trailing spaces */
  }
  return ("no error in FITS keyword  \"" + key + "\" (BUG?)");
}

func _fits_id(hdr)
/* DOCUMENT _fits_id(hdr)
     Return array  of numerical identifier  for FITS header data  HDR which
     must be  an array(char, 80,  N).  Any invalid  FITS key will  have its
     identifier set to -1.

   SEE ALSO: fits, fits_id, fits_key, fits_rehash. */
{
  digit = _fits_digitize(1 + hdr(1:8,));
  id = _fits_multiplier(+)*digit(+,);
  if (anyof((bad = (digit(min,) < 0) | ((! digit)(dif,)(min,) < 0))))
    id(where(bad)) = -1.0;
  return id;
}

func fits_key(id)
/* DOCUMENT fits_key(id)
     Convert  (array   of)  FITS   numerical  identifier(s)  ID   into  the
     corresponding string FITS keyword(s) without trailing spaces.

   SEE ALSO: fits, fits_id. */
{
  extern _fits_max_id;
  if (min(id) < 0.0 || max(id) > _fits_max_id || max(id%1.0) > 0.0)
    error, "invalid FITS floating point identifier";
  return fits_map(_fits_key, id);
}

func _fits_key(id)
/* DOCUMENT _fits_key(id)
     Private routine used by fits_key, only  useful if ID is a valid scalar
     numerical identifier.

   SEE ALSO: fits_key. */
{
  extern _fits_multiplier, _fits_alphabet;
  c = array(double, 8);
  basis = _fits_multiplier(2);
  r = id;
  for (i=1 ; i<=8 ; ++i) r = (r - (c(i) = r%basis))/basis;
  return string(&_fits_alphabet(1 + long(c)));
}

func fits_rehash(fh)
/* DOCUMENT fits_rehash(fh);
     (Re)compute array of numerical identifier for FITS handle FH (operation
     is done in-place) and return FH.

   SEE ALSO: fits, fits_id. */
{
  if (min(_car(fh,2,fits_ids(_car(fh,1)))) >= 0.0) return fh;
  error, "corrupted FITS header data";
}

/*---------------------------------------------------------------------------*/

func fits_get_bscale(fh) {
  if ((s = structof((value = fits_get(fh, _fits_id_bscale, default=1.0))))
      == double) return value; if (s == long) return double(value);
  _fits_warn, "bad value type for BSCALE"; return 1.0; }
func fits_get_bzero(fh) {
  if ((s = structof((value = fits_get(fh, _fits_id_bzero, default=0.0))))
      == double) return value; if (s == long) return double(value);
  _fits_warn, "bad value type for BZERO"; return 0.0; }
/* DOCUMENT fits_get_bscale(fh)
       -or- fits_get_bzero(fh)
     Get BSCALE and BZERO values  for FITS handle FH.  These parameters are
     used to convert file values into physical values according to:
         physical_value = BZERO + BSCALE * file_value
     if the corresponding card is  missing, BSCALE and BZERO default to 1.0
     and 0.0 respectively.

   SEE ALSO: fits, fits_get, fits_read_array, fits_write_array. */

func fits_get_gcount(fh) {
  if (structof((value = fits_get(fh, _fits_id_gcount, default=1)))
      == long) return value;
  _fits_warn, "bad value type for GCOUNT"; return 1; }
func fits_get_pcount(fh) {
  if (structof((value = fits_get(fh, _fits_id_pcount, default=0)))
      == long) return value;
  _fits_warn, "bad value type for PCOUNT"; return 0; }
/* DOCUMENT fits_get_gcount(fh)
       -or- fits_get_pcount(fh)
     Get PCOUNT and  GCOUNT values for FITS handle FH.   PCOUNT shall be an
     integer  equal  to  the  number  of parameters  preceding  each  group
     (default value 0).  GCOUNT shall be  an integer equal to the number of
     random groups present (default value  1).  The total number of bits in
     the data  array (exclusive of  fill that is  needed after the  data to
     complete the last record) is given by the following expression:

         NBITS = abs(BITPIX)*GCOUNT*(PCOUNT + NAXIS1*NAXIS2*...*NAXISm)


   SEE ALSO: fits, fits_get, fits_get_bitpix,
             fits_read_array, fits_write_array. */

func fits_get_history(fh) {
  if (structof((value = fits_get(fh, _fits_id_history))) == string
      || is_void(value)) return value;
  error, "bad value type for HISTORY"; }
func fits_get_comment(fh) {
  if (structof((value = fits_get(fh, _fits_id_comment))) == string
      || is_void(value)) return value;
  error, "bad value type for COMMENT"; }
/* DOCUMENT fits_get_history(fh)
       -or- fits_get_comment(fh)
     Get COMMENT and  HISTORY values for FITS handle FH.   The result is an
     array of string(s) or nil if no such cards exists in the header of the
     current unit.

   SEE ALSO: fits, fits_get, fits_read_array, fits_write_array. */


/*---------------------------------------------------------------------------*/
/* INITIALIZATION OF PRIVATE DATA */

local _fits_true, _fits_false;
/* DOCUMENT _fits_true
            _fits_false
     True/false FITS values ('T' and 'F' respectively). */
_fits_true = 'T';
_fits_false = 'F';

local _fits_digitize, _fits_multiplier, _fits_alphabet, _fits_max_id;
/* DOCUMENT _fits_digitize   - char -> number conversion array;
            _fits_multiplier - multiplier;
            _fits_alphabet   - allowed characters in FITS keys;
            _fits_max_id     - maximum possible ID value.
     Private  arrays  used  to   convert  FITS  keyword  to/from  numerical
     identifiers.  If you experiment  a strange behaviour of FITS routines,
     it may  be because one  of these arrays  get corrupted; in  that case,
     just  run subroutine fits_init  to reinitialize  things (you  may also
     have to rehash your FITS handles: see fits_rehash).

   SEE ALSO: fits, fits_init, fits_rehash, fits_id, fits_key. */

local _fits_id_simple, _fits_id_bitpix, _fits_id_naxis, _fits_id_end;
local _fits_id_comment, _fits_id_history, _fits_id_xtension;
local _fits_id_bscale, _fits_id_bzero, _fits_id_gcount, _fits_id_pcount;
/* DOCUMENT _fits_id_simple    _fits_id_bitpix   _fits_id_naxis
            _fits_id_end       _fits_id_comment  _fits_id_history
            _fits_id_xtension  _fits_id_bscale   _fits_id_bzero
            _fits_id_gcount    _fits_id_pcount
     Numerical  identifers of  common FITS  keywords. If  you  experiment a
     strange behaviour  of FITS  routines, it may  be because one  of these
     values get corrupted;  in that case, just run  subroutine fits_init to
     reinitialize things.

   SEE ALSO: fits, fits_init. */

local _fits_id_special;
/* DOCUMENT _fits_id_special
     Private  array  of  all  numerical  identifers of  common  FITS  keys:
     "SIMPLE",  "BITPIX",  "NAXIS", "END",  "",  "COMMENT", "HISTORY",  and
     "XTENSION".

   SEE ALSO: fits, fits_init. */

local _fits_strict;
/* DOCUMENT _fits_strict
     Private flag: apply strict FITS compliance?  Never change this flag
     directly but rather call `fits_init'.

   SEE ALSO: fits, fits_init. */


func fits_init(sloopy=, allow=, blank=)
/* DOCUMENT fits_init;
     (Re)initializes FITS private  data.  Normally you do not  have to call
     this  routine  because  this  routine  is  automatically  called  when
     "fits2.i" is  parsed by Yorick.   You may however need  to explicitely
     call  fits_init  if  you  suspect  that some  FITS  private  data  get
     corrupted or if you want to tune FITS strict/sloopy behaviour.

     If keyword SLOOPY  is true (non-nil and non-zero)  some discrepancy is
     allowed (for reading FITS file only); otherwise strict FITS compliance
     is applied.  If SLOOPY is true, lower case Latin letters have the same
     meaning  as their  upper  case counterparts,  most control  characters
     become identical to regular spaces.

     According to FITS standard, the only characters permitted for keywords
     are  upper  case  (capital)  Latin alphabetic,  numbers,  hyphen,  and
     underscore.  Leading and embedded blanks are forbidden.  If you cannot
     read a FITS file because it does not confrom to this rule, you can use
     keyword ALLOW (a string or an array of characters) to allow additional
     characters for FITS keywords.  For instance:
       fits_init, allow="/."; // fix for invalid headers made by IRAF
     make characters '/'  and '.'  acceptable in FITS  keywords.  Note that
     you  must apply fits_rehash  (to see)  to _every_  FITS handle  in use
     whenever you change  the set of allowed characters  (because this will
     probably corrupt the values of numerical identifiers of FITS card) ...
     It is  therefore a good idea  to change the set  of allowed characters
     before using any FITS routines.

     Keyword  BLANK can  be  used to  add  more characters  that should  be
     considered as blanks (spaces)  when parsing FITS header/keywords.  The
     value  of BLANK  must  be a  string  or an  array  of characters,  for
     instance: BLANK="\t\r\v\n".  Note that this break strict compliance to
     FITS standard.

   SEE ALSO: fits, fits_rehash. */
{
  extern _fits_digitize,    _fits_multiplier;
  extern _fits_alphabet,    _fits_max_id;
  extern _fits_id_simple,   _fits_id_bitpix;
  extern _fits_id_naxis,    _fits_id_end;
  extern _fits_id_comment,  _fits_id_history;
  extern _fits_id_xtension, _fits_id_extname, _fits_id_special;
  extern _fits_id_bscale,   _fits_id_bzero;
  extern _fits_id_pcount,   _fits_id_gcount;
  extern _fits_strict;

  /* Strict FITS compliance? */
  _fits_strict = (strict = (! sloopy && is_void(allow)));

  /* Prepare key<->id conversion arrays. */
  _fits_alphabet = _(, '\0', '-', '_', char(indgen('0':'9')),
                                       char(indgen('A':'Z')));
  if (! is_void(allow)) {
    /* Add more allowed characters for FITS keywords. */
    if ((s = structof(allow)) == string && ! dimsof(allow)(1)) {
      allow = *pointer(allow);
    } else if (s != char) {
      error, "value of keyword ALLOW must be a string or an array of char's";
    }
    n = numberof(allow);
    for (i=1 ; i<=n ; ++i) {
      if (noneof(allow(i) == _fits_alphabet)) grow, _fits_alphabet, allow(i);
    }
  }
  basis = numberof(_fits_alphabet);
  _fits_multiplier = double(basis)^indgen(0:7);
  _fits_max_id = sum(_fits_multiplier * (basis-1.0));
  _fits_digitize = array(-1, 256);
  _fits_digitize(1 + _fits_alphabet) = indgen(0:basis-1);

  /* Deal with "blanck/space" characters (spaces and '\0' _must_ all have
     their digitize value equal to 0). */
  if ((space = _fits_digitize(1 + '\0')) != 0)
    error, "digitize value of spaces must be zero (BUG)";
  _fits_digitize(1 + ' ') = space;
  if (! is_void(blank)) {
    if ((s = structof(blank)) == string && ! dimsof(blank)(1)) {
      blank = *pointer(blank);
    } else if (s != char) {
      error, "value of keyword BLANK must be a string or an array of char's";
    }
    _fits_digitize(1 + blank) = space;
  }

  if (! strict) {
    _fits_digitize(1 + '\t') = space;
    _fits_digitize(1 + '\r') = space;
    _fits_digitize(1 + '\v') = space;
    _fits_digitize(1 + '\n') = space;
    _fits_digitize(indgen(1+'a':1+'z')) = _fits_digitize(indgen(1+'A':1+'Z'));
  }

  /* Numerical ID's of common keys. */
  _fits_id_simple   = fits_id("SIMPLE");
  _fits_id_bitpix   = fits_id("BITPIX");
  _fits_id_naxis    = fits_id("NAXIS");
  _fits_id_history  = fits_id("HISTORY");
  _fits_id_comment  = fits_id("COMMENT");
  _fits_id_end      = fits_id("END");
  _fits_id_xtension = fits_id("XTENSION");
  _fits_id_extname  = fits_id("EXTNAME");
  _fits_id_bscale   = fits_id("BSCALE");
  _fits_id_bzero    = fits_id("BZERO");
  _fits_id_pcount   = fits_id("PCOUNT");
  _fits_id_gcount   = fits_id("GCOUNT");
  //_fits_id_extend = fits_id("EXTEND");
  _fits_id_special  = [_fits_id_simple, _fits_id_bitpix, _fits_id_naxis,
                       _fits_id_end, 0.0, _fits_id_comment, _fits_id_history,
                       _fits_id_xtension];
}

/*---------------------------------------------------------------------------*/
/* CLOSURE */

/* Initializes FITS internals (must be last statement of this file).  The
   following allows for non-standard keyword characters usually found in
   FITS files produced by IRAF... */
if (is_void(_fits_alphabet)) fits_init, allow="/."; /*  */

/*---------------------------------------------------------------------------*/
/* SUPPORT FOR OBSOLETE API */

/* Here are the _public_ routines defined in the old API:
     func fitsHeader(&header)
     func fitsFixHeader(&header)
     func fitsAddComment(&header, str)
     func fitsAddHistory(&header, str, stamp=)
     func fitsRescale(data, bitpix, &bscale, &bzero, data_min=, data_max=)
     func fitsWrite(name, data, header, rescale=, pack=)
     func fitsRead(name, &header, which=, pack=, rescale=) */

local fitsHeader, fitsFixHeader, fitsAddComment, fitsAddHistory;
local fitsRescale, fitsWrite;
func fitsObsolete(..,stamp=,data_min=,data_max=,rescale=,pack=,which=)
/* DOCUMENT obsolete FITS routines

     In order to help you to upgrade your code and use the new FITS API,
     you can use the following equivalence table:
       fitsAddComment, hdr, str;    ==>  fits_set, fh, "COMMENT", str;
       fitsAddHistory, hdr, str;    ==>  fits_set, fh, "HISTORY", str;
       fitsWrite, name, data;       ==>  fits_write, name, data;
       fitsWrite, name, data, hdr;  ==>  fits_write_array, fh, data;
       fitsRead(name);              ==>  fits_read(name);
       data = fitsRead(name, hdr);  ==>  data = fits_read(name, fh);
     where NAME is the file name, STR is a string comment, HDR is the
     header structure (obsolete but see fitsMakeOldHeader), FH is
     the (new) FITS handle and DATA is an array of numbers.

     The following old routines have no real equivalent:
       fitsHeader
       fitsFixHeader
       fitsRescale
       
   SEE ALSO: fits. */
{ error, "update your code to use new FITS API (type \"help, fits\")"; }
fitsHeader = fitsFixHeader = fitsAddComment = fitsAddHistory =
fitsRescale = fitsWrite = fitsRead = fitsObsolete;

func fitsRead(name, &header, which=, pack=, rescale=)
/* DOCUMENT a= fitsRead(filename, header)

     *** WARNING: Obsolete fits routine (see fits_read) *** 
   
     Returns the data of the  FITS file FILENAME.  If present, the optional
     argument HEADER will be used to  store the contents of the FITS header
     file (a FitsHeader structure).
     
     Keyword  WHICH may  be  used  to indicate  which  sub-array should  be
     returned.  For instance, if the array DATA with dimensions (235,453,7)
     is stored in the FITS file "data.fits", the sub-array DATA(,,4) can be
     read by:
               SUB_DATA= fitsRead("data.fits", which= 4);

     Keyword PACK, if non-nil and  non-zero, indicates that axis whith unit
     dimension  should be  ignored.  The  default  is to  ignore only  zero
     length axis.

     Keyword RESCALE, if non-nil and  zero, indicates that read data values
     should not  be rescaled according  to FITS keywords BSCALE  and BZERO.
     The default is to rescale data values  if BSCALE is not 1. or BZERO is
     not 0.

  SEE ALSO: fits, fits_read, fitsObsolete. */
{
  local fh;
  data = fits_read(name, fh, which=which, rescale=rescale /*pack=pack*/);
  header = fitsMakeOldHeader(fh);
  return data;
}

local FitsHeader;
/* DOCUMENT FitsHeader - a Yorick structure  defined to store (part of) FITS
     header information.  The structure has the following members:

     bitpix   - bits-per-pixel:  8  pixel values are unsigned bytes
                                16  pixel values are signed 2-byte integers
                                32  pixel values are signed 4-byte integers
                               -32  pixel values are 4-byte floating points
                               -64  pixel values are 8-byte floating points
     naxis    - number of axis
     axis(k)  - number of pixel along k-th axis
     bscale   - pixelValue = BZERO+BSCALE*fileValue
     bzero    - pixelValue = BZERO+BSCALE*fileValue
     bunit    - brightness unit
     datamax  - maximum data value in the file
     datamin  - minimum data value in the file
     object   - image name
     date     - date of file creation (dd/mm/yy)
     date_obs - date of data acquisition (dd/mm/yy)
     origin   - institution
     instrume - data acquisition instrument
     telescop - data acquisition telescope
     observer - observer name/identification
     history  - newline separated history lines
     comment  - newline separated comment lines
     epoch    - epoch of coordinate system (year)
     crval(k) - coord = CRVAL+(pixel-CRPIX)*CDELT
     crpix(k) - coord = CRVAL+(pixel-CRPIX)*CDELT
     cdelt(k) - coord = CRVAL+(pixel-CRPIX)*CDELT
     ctype(k) - type of physical coordinate
     crota(k) - rotation angle of axis No. #

  SEE ALSO: fits, fitsMakeOldHeader. */
struct FitsHeader {
  int    bitpix, naxis, axis(9);
  double bscale, bzero, datamax, datamin, epoch,
    crval(9), crpix(9), cdelt(9), crota(9);
  string bunit, object, date, date_obs, origin, instrume, telescop, observer,
    history, comment, ctype(9);
}

local fitsOldHeaderMembers;
local fitsOldHeaderKeywords;
func fitsMakeOldHeader(fh)
/* DOCUMENT fitsMakeOldHeader(fh)
     Convert header information in FITS handle FH into the obsolete FitsHeader
     structure.
     
   SEE ALSO: fits, FitsHeader. */
{
  hdr = FitsHeader();
  n = numberof(fitsOldHeaderMembers);
  for (i=1 ; i<=n ; ++i) {
    if (! is_void((value = fits_get(fh, fitsOldHeaderKeywords(i))))) {
      get_member(hdr, fitsOldHeaderMembers(i)) = value;
    }
  }
  nil = string(0);
  for (i=1 ; i<=hdr.naxis ; ++i) {
    hdr.axis(i)  = fits_get(fh, swrite(format="NAXIS%d", i), default=0);
    hdr.crval(i) = fits_get(fh, swrite(format="CRVAL%d", i), default=0.0);
    hdr.crpix(i) = fits_get(fh, swrite(format="CRPIX%d", i), default=0.0);
    hdr.cdelt(i) = fits_get(fh, swrite(format="CDELT%d", i), default=0.0);
    hdr.ctype(i) = fits_get(fh, swrite(format="CTYPE%d", i), default=nil);
    hdr.crota(i) = fits_get(fh, swrite(format="CROTA%d", i), default=0.0);
  }
  if (! is_void((value = fits_get(fh, "HISTORY"))))
    hdr.history = _fits_strjoin(value);
  if (! is_void((value = fits_get(fh, "COMMENT"))))
    hdr.comment = _fits_strjoin(value);
  return hdr;
}
fitsOldHeaderMembers = ["bitpix","naxis","bscale","bzero","bunit",
                        "datamax","datamin","object","date","date_obs",
                        "origin","instrume","telescop","observer","epoch"];
fitsOldHeaderKeywords = fits_toupper(fitsOldHeaderMembers);


func _fits_strjoin(s)
{
  if ((n = numberof(s)) < 1) return;
  r = s(1);
  for (i=2;i<=n;++i) r += "\n" + s(i);
  return r;
}
func _fits_strsplit(s)
{
  i = 0;
  r = array(string);
  while (s) {
    s = strtok(s, "\n");
    if (++i > numberof(r)) grow, r, array(string, numberof(r));
    r(i) = s(1);
    s = s(2);
  }
  if (i == numberof(r)) return r;
  return r(1:i);
}

/*---------------------------------------------------------------------------*/