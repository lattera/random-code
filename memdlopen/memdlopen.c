/*-
 * Copyright (c) 2022-2023, by Shawn Webb <shawn.webb@hardenedbsd.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>

#include <dlfcn.h>

#include <sys/capsicum.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>

int
main(int argc, char *argv[])
{
	const char *(*fn)(void);
	void *buf, *mfdbuf;
	struct stat sb;
	void *handle;
	int fd, mfd;

	fd = open("/usr/lib/libpcap.so", O_RDONLY);
	if (fd < 0) {
		perror("open");
		exit(1);
	}

	memset(&sb, 0, sizeof(sb));
	if (fstat(fd, &sb)) {
		perror("fstat");
		exit(1);
	}

	if (cap_enter()) {
		perror("cap_enter");
		exit(1);
	}

	buf = mmap(NULL, sb.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
	if (buf == MAP_FAILED) {
		perror("mmap");
		exit(1);
	}

	mfd = memfd_create("memdlopen", 0);
	if (mfd < 0) {
		perror("memfd_create");
		exit(1);
	}

	if (ftruncate(mfd, sb.st_size)) {
		perror("ftruncate");
		exit(1);
	}

	write(mfd, buf, sb.st_size);
	lseek(mfd, 0, SEEK_SET);
	printf("mFD: %i\n", mfd);

	munmap(buf, sb.st_size);
	close(fd);

	handle = fdlopen(mfd, RTLD_NOW | RTLD_GLOBAL);
	if (handle == NULL) {
		fprintf(stderr, "dlopen: %s\n", dlerror());
		exit(1);
	}

	memset(&sb, 0, sizeof(sb));
	if (fstat(mfd, &sb)) {
		perror("fstat(mfd)");
		exit(1);
	}

	printf("Type: ");
	if (S_ISFIFO(sb.st_mode)) {
		printf("FISO\n");
	} else if (S_ISCHR(sb.st_mode)) {
		printf("CHR\n");
	} else if (S_ISDIR(sb.st_mode)) {
		printf("DIR\n");
	} else if (S_ISBLK(sb.st_mode)) {
		printf("BLK\n");
	} else if (S_ISREG(sb.st_mode)) {
		printf("REG\n");
	} else if (S_ISLNK(sb.st_mode)) {
		printf("LNK\n");
	} else if (S_ISSOCK(sb.st_mode)) {
		printf("SOCK\n");
	} else if (S_ISWHT(sb.st_mode)) {
		printf("WHT\n");
	}
	printf("DEV: %zu\n", sb.st_dev);
	printf("INODE: %zu\n", sb.st_ino);

	close(mfd);

	shm_unlink("memfd:memdlopen");

	fn = dlsym(handle, "pcap_lib_version");

	printf("PID: %d\n", getpid());
	printf("fn @ %p\n", fn);
	if (fn != NULL) {
		printf("pcap_lib_version: %s\n", fn());
	}

	while (true) {
		sleep(5);
	}

	exit(0);
}
