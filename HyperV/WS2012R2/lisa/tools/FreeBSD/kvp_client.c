/*
 * An implementation of key value pair (KVP) functionality for FreeBSD.
 *
 * Copyright (c) 2011, Microsoft Corporation.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * This program is distributed in the hope it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program; if not, write to the Free Software Foundation, Inc., 59 Temple
 * Place - Suite 330, Boston, MA 02111-1307 USA.
 *
 * Authors:
 * 	K. Y. Srinivasan <kys@microsoft.com>
 */

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/poll.h>
#include <sys/utsname.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <netdb.h>
#include <syslog.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <getopt.h>

#ifndef FREEBSD
#define FREEBSD
#endif


#ifndef FREEBSD
#include <linux/types.h>
#include <linux/connector.h>
#include <linux/hyperv.h>
#include <linux/netlink.h>
#else
#include <arpa/inet.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <net/if_dl.h>
#include <net/if_types.h>
#include "hv_kvp.h"
#include "connector.h"
#endif


struct kvp_record {
	__u8 key[HV_KVP_EXCHANGE_MAX_KEY_SIZE];
	__u8 value[HV_KVP_EXCHANGE_MAX_VALUE_SIZE];
};

/* The required_values structure data elements pool_number and required_kvp_record
   will be populated with values obtained from the command line.  The localoption 
   data element will be assigned with some logic.
 */ 
struct required_values{
	int pool_number;
	struct kvp_record required_kvp_record;
	int localoption;
};

#define NUM_POOLS		5					

#define USAGE_HELP	 	0
#define LIST_USAGE 		1
#define APPEND_USAGE 		2
#define MODIFY_USAGE 		3
#define DELETE_USAGE 		4

#define EXITING_WITH_ERROR 	-1

#define ALL_RECORDS_OF_ALL_POOLS	1 //unused
#define ALL_RECORDS_OF_POOL 		2
#define RECORDS_OF_KEY_POOL		3
#define RECORD_OF_KEY 			4

typedef enum {FALSE, TRUE}bool_enum;  // to handle the flags

static void kvp_acquire_lock(int fd)
{
#ifndef FREEBSD
	struct flock fl = {F_RDLCK, SEEK_SET, 0, 0, 0};
#else
	struct flock fl = {0, 0, 0, F_RDLCK, SEEK_SET, 0};
#endif
	fl.l_pid = getpid();

	if (fcntl(fd, F_SETLKW, &fl) == -1) {
		perror("fcntl lock");
		exit(EXITING_WITH_ERROR);
	}
}

static void kvp_release_lock(int fd)
{
#ifndef FREEBSD
	struct flock fl = {F_UNLCK, SEEK_SET, 0, 0, 0};
#else
	struct flock fl = {0, 0, 0, F_UNLCK, SEEK_SET, 0};
#endif
	fl.l_pid = getpid();

	if (fcntl(fd, F_SETLK, &fl) == -1) {
		perror("fcntl unlock");
		exit(EXITING_WITH_ERROR);
	}
}

/*
 * Retrieve the records from a specific pool.
 *
 * pool: specific pool to extract the records from.
 * buffer: Client allocated memory for reading the records to.
 * num_records: On entry specifies the size of the buffer; on exit this will
 * have the number of records retrieved.
 * more_records: set to non-zero to indicate that there are more records in the pool
 * than could be retrieved. This indicates that the buffer was too small to
 * retrieve all the records.
 */

int kvp_read_records(int pool, struct kvp_record *buffer, int *num_records,
		int *more_records)
{
	int  fd;
	int  error = 0;
	FILE *filep;
	size_t records_read;
	__u8 fname[50] = {0};

	sprintf(fname, "/var/db/hyperv/pool/.kvp_pool_%d", pool);
	fd = open(fname, S_IRUSR);
	if (fd == -1) {
		perror("Open failed");
		exit(EXITING_WITH_ERROR);
	}

	filep = fopen(fname, "r");
	if (!filep) {
		close (fd);
		perror("fopen failed");
		exit(EXITING_WITH_ERROR);
	}

	kvp_acquire_lock(fd);
	records_read = fread(buffer, sizeof(struct kvp_record),
			*num_records,
			filep);
	kvp_release_lock(fd);

/*	In hyperv 2012, the following statement will always return true, comment it
	if (ferror(filep)) {
		error = 1;
		goto done;
	}
*/
	//	if (!feof(filep))
	//		*more_records = 1;

	*num_records = records_read;

done:
	close (fd);
	fclose(filep);
	return error;
}

/*
 * kvp_append_record() function accepts required values to append from the structure and append that  record to a specific pool.
 * structre contains the following things:
 * pool: specific pool to append the record to
 *
 * key: key to be appended in the record
 *
 * value: value to be appended in the record
 */

int kvp_append_record( struct required_values append)
{
	int  fd;
	FILE *filep;
	__u8 fname[50];
	struct kvp_record write_buffer;

	memset(write_buffer.key, 0, strlen(append.required_kvp_record.key)+1);
	memset(write_buffer.value, 0, strlen(append.required_kvp_record.value)+1);

	memcpy(write_buffer.key, append.required_kvp_record.key, strlen(append.required_kvp_record.key)+1);
	memcpy(write_buffer.value, append.required_kvp_record.value, strlen(append.required_kvp_record.value)+1);

	sprintf(fname, "/var/db/hyperv/pool/.kvp_pool_%d", append.pool_number);
	fd = open(fname, S_IRUSR);

	if (fd == -1) {
		perror("Open failed");
		exit(EXITING_WITH_ERROR);
	}

	filep = fopen(fname, "a");
	if (!filep) {
		close (fd);
		perror("fopen failed");
		exit(EXITING_WITH_ERROR);
	}

	kvp_acquire_lock(fd);
	fwrite(&write_buffer, sizeof(struct kvp_record),
			1, filep);
	kvp_release_lock(fd);

	close (fd);
	fclose(filep);
	return 0;
}

/*
 * kvp_modify_record() : Modifies an existing record of specific pool. The details of the record to be modified will be specified by the stucture.
 * structure contains the following:
 * pool: specific pool to modify the record to.
 *
 * key: key in the record
 *
 * value: value to replace
 *
 */

int kvp_modify_record(struct required_values modify)
{
	int  fd;
	FILE *filep;
	__u8 fname[50];

	int i;
	int more;
	int num_records;
	struct kvp_record my_records[200];

	if (kvp_read_records(modify.pool_number, my_records, &num_records, &more)) {
		printf("kvp_read_records failed\n");
		exit(EXITING_WITH_ERROR);
	}

	sprintf(fname, "/var/db/hyperv/pool/.kvp_pool_%d", modify.pool_number);
	fd = open(fname, S_IRUSR);

	if (fd == -1) {
		perror("Open failed");
		exit(EXITING_WITH_ERROR);
	}

	kvp_acquire_lock(fd);
	filep = fopen(fname, "w");
	if (!filep) {
		close (fd);
		perror("fopen failed");
		exit(EXITING_WITH_ERROR);
	}

	for (i = 0; i < num_records; i++) {
		if (strcmp(my_records[i].key, modify.required_kvp_record.key) == 0) {
			memset(my_records[i].value, 0, strlen(my_records[i].value));
			strcpy(my_records[i].value, modify.required_kvp_record.value);
			printf("key %s is modified with value %s\n ", my_records[i].key, my_records[i].value);
		}
	}

	fwrite(&my_records, sizeof(struct kvp_record),
			num_records, filep);

	kvp_release_lock(fd);

	close (fd);
	fclose(filep);
	return 0;
}

/*
 * kvp_list_records(): This function performs the following operations:
 * 1.It lists contents of a specific record of specific pool 
 * 2.It lists all the records specific to the pool.
 * 3.It lists all the records specific to a key in any pool.
 *
 */

int kvp_list_records(struct required_values list)
{
	int i, pool;
	int more;
	int num_records = 200;
	struct kvp_record my_records[200];

	switch (list.localoption) {
		case ALL_RECORDS_OF_POOL:
			if(kvp_read_records(list.pool_number, my_records, &num_records, &more)){
				printf("kvp_read_records failed\n");
				exit(EXITING_WITH_ERROR);
			}	
			printf("Pool is %d; Number of records are :%d\n", list.pool_number, num_records);
			for (i=0; i <num_records; i++){
				printf("\tKey : %s; Value : %s;\n", my_records[i].key, my_records[i].value);
			}
			break;

		case RECORDS_OF_KEY_POOL:
			if(kvp_read_records(list.pool_number, my_records, &num_records, &more)){
				printf("kvp_read_records failed\n");
				exit(EXITING_WITH_ERROR);
			}	
			printf("Pool is %d; Number of records are :%d\n", list.pool_number, num_records);
			for (i =0; i < num_records; i++){
				if(strcmp(my_records[i].key, list.required_kvp_record.key) == 0)
					printf("\tKey : %s; Value : %s;\n", my_records[i].key, my_records[i].value);
			}
			break;	

		case RECORD_OF_KEY:
			if (kvp_read_records(list.pool_number, my_records, &num_records, &more)) {
				printf("kvp_read_records failed\n");
				exit(EXITING_WITH_ERROR);
			}
			for (i=0; i <num_records; i++){
				if(strcmp(my_records[i].key, list.required_kvp_record.key)== 0)
					printf("\nPool is : %d; Key : %s; Value : %s;\n", list.pool_number, my_records[i].key, my_records[i].value);
			}
			break;
		default:
			printf("List option is wrong\n");
			break;
	}

}

/*
 * kvp_delete_records():Performs following operations:
 * 1.Delete a record from a specific pool. 
 * 2.Delete all records of a specific pool.
 * The follownig will be specified by the structure. 
 * pool: specific pool to delete the record from.
 * key: key in the record
 *
 */

int kvp_delete_records( struct required_values delete)
{
	int  fd,err;
	FILE *filep;
	__u8 fname[50];

	int i;
	int more;
	int num_records = 200;
	struct kvp_record my_records[200]; 
	struct required_values temp_record;

	if (kvp_read_records(delete.pool_number, my_records, &num_records, &more)) {
		printf("kvp_read_records failed\n");
		exit(EXITING_WITH_ERROR);
	}
	sprintf(fname, "/var/db/hyperv/pool/.kvp_pool_%d", delete.pool_number);
	fd = open(fname, S_IRUSR);
	if (fd == -1) {
		perror("Open failed");
		exit(EXITING_WITH_ERROR);
	}

	kvp_acquire_lock(fd);
	filep = fopen(fname, "w");
	if (!filep) {
		close (fd);
		perror("fopen failed");
		exit(EXITING_WITH_ERROR);
	}

	switch(delete.localoption) {
		case ALL_RECORDS_OF_POOL:
			err = truncate(fname, 0);
			if(err == -1) {
				printf("kvp_delete_records failed.\n");
				exit(EXITING_WITH_ERROR);
			}
			break;

		case RECORDS_OF_KEY_POOL:
			for (i = 0; i < num_records; i++) {
				if (strcmp(my_records[i].key, delete.required_kvp_record.key) != 0) {
					temp_record.pool_number = delete.pool_number;
					strcpy(temp_record.required_kvp_record.key, my_records[i].key);
					strcpy(temp_record.required_kvp_record.value, my_records[i].value);
					kvp_append_record(temp_record);
				}
			}
			break;
	}
	kvp_release_lock(fd);
	close (fd);
	fclose(filep);
	return 0;
}

/*
 * Confirm a record exists in a specific pool.
 *
 * pool: specific pool to check the existance of the record .
 * key: key in the record
 *
 */

int kvp_key_exists(int pool, __u8 *key)
{
	int i;
	int more;
	int num_records = 200;	//set the initial number of records to read
	struct kvp_record my_records[200];

	if (kvp_read_records(pool, my_records, &num_records, &more)) {
		printf("kvp_read_records failed\n");
		exit(-1);
	}
	for (i = 0; i < num_records; i++) {
		if (strcmp(my_records[i].key, key) == 0) {
			return 0;
		}
	}
	return 1;
}

bool_enum get_user_conscent(struct required_values temp){
	char ch;
	if((temp.pool_number >= 0 && temp.pool_number < NUM_POOLS) && strcmp(temp.required_kvp_record.key, "") != 0)
		printf("Are you sure that you want to delete key %s of pool %d? [Y/N]N:", temp.required_kvp_record.key, temp.pool_number);
	else if((temp.pool_number >= 0 && temp.pool_number < NUM_POOLS))
		printf("Are you sure that you want to delete all records of pool %d? [Y/N]N:", temp.pool_number);
	else
		printf("Are you sure that you want to delete all records of pool %d? [Y/N]N:", temp.pool_number);

	ch = getchar();
	if( ch == 45 || ch == 32 || ch == 10) {
		printf("Default is No, Hence, Not performing delete operation\n");
		return FALSE;
	}else if (ch == 'Y' || ch == 'y'){ 
		return TRUE;
	}
	else {
		printf("Not performing delete operation\n");
		return FALSE;
	}
}

/*
 * describes about usage of different options.
 */

void usage(char *name, int option)
{
	switch(option){
		case LIST_USAGE:
			printf ("Usage:%s -l/--list [-p/--pool pool_number] [-k/--key  keyname]\n", name);
			break;
		case APPEND_USAGE:
			printf ("Usage:%s -a/--add -p/--pool pool_number -k/--key keyname -v/--value keyvalue\n", name);
			break;
		case MODIFY_USAGE:
			printf ("Usage:%s -m/--modify -p/--pool pool_number -k/--key keyname -v/--value keyvalue\n", name);
			break;
		case DELETE_USAGE:
			printf ("Usage:%s -d/--delete [-p/--pool pool_number] [-k/--key keyname]\n", name);
			break;
		case USAGE_HELP:
			printf ("Usage:%s -l/--list [-p/--pool pool_number] [-k/--key  keyname]\n", name);
			printf ("or\t%s -a/--add -p/--pool pool_number -k/--key keyname -v/--value keyvalue\n", name);
			printf ("or\t%s -m/--modify -p/--pool pool_number -k/--key keyname -v/--value keyvalue\n", name);
			printf ("or\t%s -d/--delete [-p/--pool pool_number] [-k/--key keyname]\n", name);
			break;
		default:
			break;
	}
	exit(0);
}


struct kvp_record my_records[200]; 
int main (int argc, char *argv[]) {

	int option_index = 0;
	bool_enum list, modify, append, delete;
	bool_enum pool_flag, key_flag, value_flag;
	int i,c,pool;
	char *key, *value;
	char ch;
	struct required_values option;

	list=modify=append=delete = FALSE;
	pool_flag=key_flag=value_flag = FALSE;

	struct option long_options[] ={
		{"list", no_argument, 0, 'l'},
		{"modify", no_argument, 0, 'm'},
		{"add", no_argument, 0, 'a'},
		{"delete", no_argument, 0, 'd'},
		{"help", no_argument, 0, 'h'},
		{"pool", required_argument, 0, 'p'},
		{"key", required_argument, 0, 'k'},
		{"value", required_argument, 0, 'v'},
		{0,0,0,0}
	};

	memset(&option, 0, sizeof(struct required_values));

	while(c = getopt_long (argc, argv, "hlmadp:k:v:",long_options, &option_index)) {
		if (c == -1){
			break;
		}
		switch(c) {
			case 'l':
				list = TRUE;
				break;
			case 'm':
				modify = TRUE;
				break;
			case 'a':
				append = TRUE; 
				break;
			case 'd':
				delete = TRUE;
				break;
			case 'p':
				option.pool_number = atoi(optarg);
				if ( option.pool_number < 0 || option.pool_number > 4) {
					printf("Pool number should be with in range of 0 to 4\n");
					return(EXITING_WITH_ERROR);
				}	
				pool_flag = TRUE;
				break;
			case 'k':
				if (strlen(optarg) > HV_KVP_EXCHANGE_MAX_KEY_SIZE -1){
					fprintf(stderr, "Key string is too long\n");
					exit (EXITING_WITH_ERROR);
				}
				strcpy(option.required_kvp_record.key, optarg);
				key_flag = TRUE;
				break;	
			case 'v':
				if (strlen(optarg) > HV_KVP_EXCHANGE_MAX_VALUE_SIZE -1){
					fprintf(stderr, "Value string is too long\n");
					exit (EXITING_WITH_ERROR);
				}
				value_flag = TRUE;
				strcpy(option.required_kvp_record.value, optarg);	
				break;	
			case 0:
			case 'h':
			default:
				usage(argv[0], USAGE_HELP);
				break;
		}		
	}	

	// check atleast one of list, modify and delete options needs to be given
	if (!(list||modify||append||delete)){
		usage(argv[0],USAGE_HELP);
		return (EXITING_WITH_ERROR);
	}


	/*
	   -l  ----> List all records of all pools : kvp_list_records()
	   -l -p # --> List all records of  that pool # : kvp_list_records()
	   -l -p # -k <key> --> List value of the <key> of  that pool # : kvp_list_records()
	   -l -k <key> --->List the values of the <key> from in all pools : kvp_list_records()
	 */
	if(list && !(modify ||append || delete)){
		if(pool_flag){
			if(key_flag) {
				if(kvp_key_exists(option.pool_number, option.required_kvp_record.key) == 0)
					option.localoption = RECORDS_OF_KEY_POOL;
				else{
					printf("Key %s is not in pool %d.\n", option.required_kvp_record.key, option.pool_number);
					return 0;
				}
			}
			else option.localoption = ALL_RECORDS_OF_POOL;

		}else{
			if (key_flag)
				option.localoption = RECORD_OF_KEY;
			else 
				option.localoption = ALL_RECORDS_OF_POOL;
			for (i=0; i < NUM_POOLS; i++){
				option.pool_number = i;
				kvp_list_records(option);
			}
			return 0;
		}
		kvp_list_records(option);
		return 0;
	}else if(list) usage(argv[0], LIST_USAGE);

	/*
	   -m -p # -k <key> -v <value> ---> modify the record of the key of the pool # to value : kvp_modify_record()

	 */
	if(modify && !(list ||append || delete)) {
		if(!(pool_flag && key_flag && value_flag))
			usage(argv[0], 3);
		else{
			if(kvp_key_exists(option.pool_number, option.required_kvp_record.key) == 0)
				kvp_modify_record(option);
			else
				printf("Key %s is not in pool %d.\n", option.required_kvp_record.key, option.pool_number);
		}
		return 0;
	}else if(modify) usage(argv[0], MODIFY_USAGE);	

	/*
	   -a -p # -k <key> -v <value> --> append the key and value record to the pool # : kvp_append_record()

	 */		
	if(append && !(modify|| delete||list)){
		if(!(pool_flag && key_flag && value_flag))
			usage(argv[0], 2);
		else{
			if(kvp_key_exists(option.pool_number, option.required_kvp_record.key) != 0)
				if(kvp_append_record(option)==0) printf("\n Append Record Successful\n");
				else printf("\n Append Record not Successful\n");
			else
				printf("Key %s is already in pool %d.You Cannot create a duplicate one.\n", option.required_kvp_record.key, option.pool_number);
		}		
		return 0;
	}else if(append) usage(argv[0], APPEND_USAGE);	

	/*
	   -d --> delete all the records of all the pools, currently not enabled
	   -d -p # --> delete all the records of pool # 
	   -d -p # -k <key> --> delete the record of key of pool # 
	 */
	if(delete && !(list || modify || append)){
		if(pool_flag){
			if(key_flag){
				if (kvp_key_exists(option.pool_number, option.required_kvp_record.key) != 0)  {
					printf(" Key %s is not in pool %d\n", option.required_kvp_record.key, option.pool_number);
					exit(EXITING_WITH_ERROR);
				}
				if (get_user_conscent(option))
					option.localoption = RECORDS_OF_KEY_POOL;
				else
					return 0;
			} else{
				if (get_user_conscent(option))
					option.localoption = ALL_RECORDS_OF_POOL;
				else
					return 0;
			}
			kvp_delete_records(option);
			printf("Delete operation of %s key of pool %d is successfull\n", option.required_kvp_record.key, option.pool_number);
		} else if(delete) usage(argv[0], DELETE_USAGE);
		/*else {  Not enabled  to avaoid human errors.
		  if(get_user_conscent) {
		  for(i=0; i < NUM_POOLS; i++){
		  option.localoption = ALL_RECORDS_OF_POOL;
		  option.pool_number = i;
		  kvp_delete_records(option);
		  }
		  }
		  } */
	}
	return 0;
}

