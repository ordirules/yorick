/*
 * $Id: files.c,v 1.1 2005-09-18 22:05:39 dhmunro Exp $
 * UNIX version of play file operations
 */
/* Copyright (c) 2005, The Regents of the University of California.
 * All rights reserved.
 * This file is part of yorick (http://yorick.sourceforge.net).
 * Read the accompanying LICENSE file for details.
 */

#ifndef _POSIX_SOURCE
/* to get fileno declared */
#define _POSIX_SOURCE 1
#endif
#ifndef _XOPEN_SOURCE
/* to get popen declared */
#define _XOPEN_SOURCE 1
#endif

#include "config.h"
#include "pstdio.h"
#include "pstdlib.h"
#include "playu.h"

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>

struct p_file {
  FILE *fp;  /* use FILE* for text file operations */
  int fd;    /* use file descriptor for binary file operations */
  int binary;
};

p_file *
p_fopen(const char *unix_name, const char *mode)
{
  FILE *fp = fopen(u_pathname(unix_name), mode);
  p_file *f = fp? p_malloc(sizeof(p_file)) : 0;
  if (f) {
    f->fp = fp;
    f->fd = fileno(fp);
    for (; mode[0] ; mode++) if (mode[0]=='b') break;
    f->binary = (mode[0]=='b');
    u_fdwatch(f->fd, 1);
  }
  return f;
}

p_file *
p_popen(const char *command, const char *mode)
{
#ifndef NO_PROCS
  FILE *fp = popen(command, mode[0]=='w'? "w" : "r");
  p_file *f = fp? p_malloc(sizeof(p_file)) : 0;
  if (f) {
    f->fp = fp;
    f->fd = fileno(fp);
    f->binary = 2;
    u_fdwatch(f->fd, 1);
  }
  return f;
#else
  return (p_file *)0;
#endif
}

int
p_fclose(p_file *file)
{
  int flag = (file->binary&2)? pclose(file->fp) : fclose(file->fp);
  u_fdwatch(file->fd, 0);
  p_free(file);
  return flag;
}

/* could make closeall/fdwatch ultra-clever,
 * but dumb-and-simple seems to work just as well
 */
static int u_fd_max = 16;  /* minimum possible OPEN_MAX in POSIX limits.h */
void
u_closeall(void)
{
  int i;
  for (i=3 ; i<u_fd_max ; i++) close(i);
}
void
u_fdwatch(int fd, int on)
{
  if (on && fd>=u_fd_max) u_fd_max = fd+1;
}

char *
p_fgets(p_file *file, char *buf, int buflen)
{
  return fgets(buf, buflen, file->fp);
}

int
p_fputs(p_file *file, const char *buf)
{
  return fputs(buf, file->fp);
}

unsigned long
p_fread(p_file *file, void *buf, unsigned long nbytes)
{
  if (file->binary & 1)
    return read(file->fd, buf, nbytes);
  else
    return fread(buf, 1, nbytes, file->fp);
}

unsigned long
p_fwrite(p_file *file, const void *buf, unsigned long nbytes)
{
  if (file->binary & 1)
    return write(file->fd, buf, nbytes);
  else
    return fwrite(buf, 1, nbytes, file->fp);
}

unsigned long
p_ftell(p_file *file)
{
  if (file->binary & 1)
    return lseek(file->fd, 0L, SEEK_CUR);
  else if (!(file->binary & 2))
    return ftell(file->fp);
  else
    return -1L;
}

int
p_fseek(p_file *file, unsigned long addr)
{
  if (file->binary & 1)
    return -(lseek(file->fd, addr, SEEK_SET)==-1L);
  else if (!(file->binary & 2))
    return fseek(file->fp, addr, SEEK_SET);
  else
    return -1;
}

int
p_fflush(p_file *file)
{
  return (file->binary & 1)? 0 : fflush(file->fp);
}

int
p_feof(p_file *file)
{
  return feof(file->fp);  /* does not work for file->binary */
}

int
p_ferror(p_file *file)
{
  int flag = ferror(file->fp);
  clearerr(file->fp);
  return flag;
}

unsigned long
p_fsize(p_file *file)
{
  struct stat buf;
  if (fstat(file->fd, &buf)) return 0;
  return buf.st_size;
}

int
p_remove(const char *unix_name)
{
  return remove(u_pathname(unix_name));
}

int
p_rename(const char *unix_old, const char *unix_new)
{
  char old[P_WKSIZ+1];
  old[0] = '\0';
  strncat(old, u_pathname(unix_old), P_WKSIZ);
  return rename(old, u_pathname(unix_new));
}

char *
p_native(const char *unix_name)
{
  return p_strcpy(u_pathname(unix_name));
}