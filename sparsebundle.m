#import <Foundation/Foundation.h>
#include <limits.h>

/*
TODO
- Test
- Write comments
- Plug into Mini vMac
- Locking
- Don't write zeros
- Read-only opening?
- Don't use asprintf
- Convert to Mini vMac style
- Convert to Mini vMac typedefs
- Better band caching
- Abstract out platform things: open, read/write, locking
- Write custom plist reader
*/

typedef struct {
  const char *path;
  off_t size;
  off_t band_size;
} sparsebundle;


bool sparsebundle_read_plist(const char *plist, off_t *band_size,
  off_t *total_size);

sparsebundle *sparsebundle_open(const char *path);
void sparsebundle_close(sparsebundle *sb);

typedef bool (*sparsebundle_op)(sparsebundle *sb, size_t band_index, char *buf,   size_t nbyte, off_t offset);
bool sparsebundle_op_read(sparsebundle *sb, size_t band_index, char *buf,
  size_t nbyte, off_t offset);
bool sparsebundle_op_write(sparsebundle *sb, size_t band_index, char *buf,
  size_t nbyte, off_t offset);

ssize_t sparsebundle_do(sparsebundle *sb, sparsebundle_op op, void *buf,
  size_t nbyte, off_t offset);

ssize_t sparsebundle_read(sparsebundle *sb, void *buf, size_t nbyte,
  off_t offset);
ssize_t sparsebundle_write(sparsebundle *sb, void *buf, size_t nbyte,
  off_t offset);

int sparsebundle_open_band(sparsebundle *sb, off_t band_index, int flags,
  bool *noband);


bool sparsebundle_read_plist(const char *plist, off_t *band_size,
  off_t *total_size) {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *path = [fileManager stringWithFileSystemRepresentation: plist
    length: strlen(plist)];
  NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: path];

  id value = [dict objectForKey: @"diskimage-bundle-type"];
  if (![@"com.apple.diskimage.sparsebundle" isEqual: value]) {
    return false;
  }

  off_t size = [[dict objectForKey: @"band-size"] longLongValue];
  if (size == 0) {
    return false;
  }
  if (band_size) {
    *band_size = size;
  }

  size = [[dict objectForKey: @"size"] longLongValue];
  if (size == 0) {
    return false;
  }
  if (total_size) {
    *total_size = size;
  }

  return true;
}

sparsebundle *sparsebundle_open(const char *path) {
  char *plist;
  if (asprintf(&plist, "%s/%s", path, "Info.plist") == -1) {
    return NULL;
  }
  off_t band_size, total_size;
  bool ok = sparsebundle_read_plist(plist, &band_size, &total_size);
  free(plist);
  if (!ok) {
    return NULL;
  }

  sparsebundle *sb = malloc(sizeof(sparsebundle));
  if (!sb) {
    return NULL;
  }
  sb->path = path;
  sb->size = total_size;
  sb->band_size = band_size;
  return sb;
}

void sparsebundle_close(sparsebundle *sb) {
  if (sb) {
    sb->path = NULL;
    free(sb);
  }
}

int sparsebundle_open_band(sparsebundle *sb, off_t band_index, int flags,
  bool *noband) {
  if (noband) {
    *noband = false;
  }

  if (!sb) {
    return -1;
  }

  // Check if the band is in range.
  if (band_index < 0 || band_index * sb->band_size >= sb->size) {
    return -1;
  }

  char *path;
  if (asprintf(&path, "%s/bands/%llx", sb->path, band_index) == -1) {
    return -1;
  }
  int fd = open(path, flags);
  free(path);

  if (fd == -1 && errno == ENOENT && noband) {
    *noband = true;
  }
  return fd;
}

ssize_t sparsebundle_do(sparsebundle *sb, sparsebundle_op op, void *buf,
  size_t nbyte, off_t offset) {
  if (!sb) {
    return -1;
  }

  if (offset < 0 || offset > sb->size) {
    return -1;
  }
  if (offset == sb->size) {
    return 0;
  }
  if (nbyte > sb->size - offset) {
    nbyte = sb->size - offset;
  }

  char *cbuf = buf;
  char *bufend = cbuf + nbyte;

  size_t band_index = offset / sb->band_size;
  offset = offset % sb->band_size;

  while (cbuf < bufend) {
    size_t len = bufend - cbuf;
    size_t avail = sb->band_size - offset;
    if (len > avail) {
      len = avail;
    }

    if (!op(sb, band_index, cbuf, len, offset)) {
      return -1;
    }

    cbuf += len;
    offset = 0;
    band_index += 1;
  }

  return nbyte;
}

bool sparsebundle_op_read(sparsebundle *sb, size_t band_index, char *buf,
  size_t nbyte, off_t offset) {
  bool noband = false;
  int fd = sparsebundle_open_band(sb, band_index, O_RDONLY, &noband);

  if (fd == -1 && !noband) {
    return false;
  }

  if (fd != -1) {
    ssize_t did_read = pread(fd, buf, nbyte, offset);
    close(fd);
    if (did_read == -1) {
      return false;
    }
    buf += did_read;
    nbyte -= did_read;
  }
  if (nbyte) {
    memset(buf, 0, nbyte);
  }
  return true;
}

bool sparsebundle_op_write(sparsebundle *sb, size_t band_index, char *buf,
  size_t nbyte, off_t offset) {
  int fd = sparsebundle_open_band(sb, band_index, O_WRONLY | O_CREAT, NULL);

  if (fd == -1) {
    return false;
  }

  ssize_t did_write = pwrite(fd, buf, nbyte, offset);
  close(fd);
  return did_write == nbyte;
}

ssize_t sparsebundle_read(sparsebundle *sb, void *buf, size_t nbyte,
  off_t offset) {
  return sparsebundle_do(sb, &sparsebundle_op_read, buf, nbyte, offset);
}

ssize_t sparsebundle_write(sparsebundle *sb, void *buf, size_t nbyte,
  off_t offset) {
  return sparsebundle_do(sb, &sparsebundle_op_write, buf, nbyte, offset);
}


#define BLOCKSIZE 1048575

int main(int argc, char *argv[])
{
    if (argc != 2) {
        return -1;
    }

    const char *path = argv[1];
    sparsebundle *sb = sparsebundle_open(path);
    if (!sb) {
        fprintf(stderr, "sparsebundle_open\n");
        return -1;
    }

    FILE *fout = fopen("out", "w");
    char *block = malloc(BLOCKSIZE);
    for (size_t i = 0; ; i++) {
        ssize_t r = sparsebundle_read(sb, block, BLOCKSIZE, i * BLOCKSIZE);
        if (r == -1) {
            fprintf(stderr, "sparsebundle_open\n");
            return -1;
        }
        fprintf(stderr, "block %ld: %ld\n", i, r);
        if (r) {
            fwrite(block, r, 1, fout);
        }
        if (r < BLOCKSIZE) {
            break;
        }
    }
    fclose(fout);

    sparsebundle_close(sb);

    return 0;
}
