#!/usr/bin/env python

import os
import sys
import argparse

# get all .log files from a specific folder.
# identify machines
# identify 3 tests:
#   - 4K 100% read, 100% random
#   - 4K 100% write, 100% random
#   - 8K 70% read, 30% write, 100% random


# log file name format:
# [VM_NAME]-[TEST_DESC]-[ITERATION]-test.log

TERSE_VERSION = 0
FIO_VERSION = 1
JOB_NAME = 2
GROUP_ID = 3
ERROR = 4
READ_TOTAL_IO = 5
READ_BANDWIDTH = 6
READ_IOPS = 7
READ_RUNTIME = 8
READ_LATENCY_MIN = READ_RUNTIME + 29
READ_LATENCY_MAX = READ_LATENCY_MIN + 1
READ_LATENCY_MEAN = READ_LATENCY_MIN + 2
READ_LATENCY_DEV = READ_LATENCY_MIN + 3

WRITE_TOTAL_IO = READ_LATENCY_DEV + 6
WRITE_BANDWIDTH = WRITE_TOTAL_IO + 1
WRITE_IOPS = WRITE_BANDWIDTH + 1
WRITE_RUNTIME = WRITE_IOPS + 1
WRITE_LATENCY_MIN = WRITE_RUNTIME + 29
WRITE_LATENCY_MAX = WRITE_LATENCY_MIN + 1
WRITE_LATENCY_MEAN = WRITE_LATENCY_MIN + 2
WRITE_LATENCY_DEV = WRITE_LATENCY_MIN + 3


tests= {}

def build_arg_parser():
    parser = argparse.ArgumentParser(description='Parses output of FIO for future process', add_help=True)
    parser.add_argument('-o', metavar='output', dest='output', help='Output csv file name')
    parser.add_argument('-d', metavar='directory', dest='directory', help='Input directory')

    return parser

def process_folder(folder_name, output_name):
    allfiles = os.listdir(folder_name)

    for f in allfiles:
        filename = str(f)
        if filename.endswith('-test.log'):
            # parse file name
            # read from the end
            name_parts = filename.split('-')[::-1]

            iteration = name_parts[1]

            test_desc = ''
            vm_name = ''
            desc_complete = False
            for x in name_parts[2:]:
                if desc_complete == True:
                    vm_name = x + '-' + vm_name
                    continue

                test_desc = x + '-' + test_desc
                if x == '4k' or x == '8k':
                    desc_complete = True

            vm_name = vm_name[:-1]
            test_desc = test_desc[:-1]

            # print vm_name, test_desc, iteration

            # read a terse log file
            logfile = open(os.path.join(folder_name, filename), 'r')
            content = logfile.read()

            terse_list = content.split(';')

            if test_desc not in tests:
                tests[test_desc] = {}

            if vm_name not in tests[test_desc]:
                tests[test_desc][vm_name] = {}

            if 'read' not in tests[test_desc][vm_name]:
                tests[test_desc][vm_name]['read'] = {}

            if 'write' not in tests[test_desc][vm_name]:
                tests[test_desc][vm_name]['write'] = {}


            if iteration not in tests[test_desc][vm_name]['read']:
                tests[test_desc][vm_name]['read'][iteration] = {}

            if iteration not in tests[test_desc][vm_name]['write']:
                tests[test_desc][vm_name]['write'][iteration] = {}


            tests[test_desc][vm_name]['read'][iteration]['bandwidth'] = terse_list[READ_BANDWIDTH]
            tests[test_desc][vm_name]['read'][iteration]['iops'] = terse_list[READ_IOPS]
            tests[test_desc][vm_name]['read'][iteration]['latency_min'] = terse_list[READ_LATENCY_MIN]
            tests[test_desc][vm_name]['read'][iteration]['latency_max'] = terse_list[READ_LATENCY_MAX]
            tests[test_desc][vm_name]['read'][iteration]['latency_mean'] = terse_list[READ_LATENCY_MEAN]
            tests[test_desc][vm_name]['read'][iteration]['latency_dev'] = terse_list[READ_LATENCY_DEV]

            tests[test_desc][vm_name]['write'][iteration]['bandwidth'] = terse_list[WRITE_BANDWIDTH]
            tests[test_desc][vm_name]['write'][iteration]['iops'] = terse_list[WRITE_IOPS]
            tests[test_desc][vm_name]['write'][iteration]['latency_min'] = terse_list[WRITE_LATENCY_MIN]
            tests[test_desc][vm_name]['write'][iteration]['latency_max'] = terse_list[WRITE_LATENCY_MAX]
            tests[test_desc][vm_name]['write'][iteration]['latency_mean'] = terse_list[WRITE_LATENCY_MEAN]
            tests[test_desc][vm_name]['write'][iteration]['latency_dev'] = terse_list[WRITE_LATENCY_DEV]

    #print tests

    fout = open(output_name, 'w')

    fout.write('test description,vm name,average iops (read),average iops (write),average bandwidth (read),average bandwidth (write),average latency (min) (read),average latency (min) (write),average latency (max) (read),average latency (max) (write),average latency (mean) (read),average latency (mean) (write),average latency (std. dev.) (read),average latency (std. dev.) (write)\n')
    for test_desc in tests:
        #print test_desc
        for vm_name in tests[test_desc]:
            #print '\t', vm_name, ':'
            #print '\t\t', 'read:', 

            read_avg_bandwidth = 0
            read_avg_iops = 0
            read_avg_lat_min = 0
            read_avg_lat_max = 0
            read_avg_lat_mean = 0
            read_avg_lat_dev = 0
            for it in tests[test_desc][vm_name]['read']:
                read_avg_bandwidth += float(tests[test_desc][vm_name]['read'][it]['bandwidth'])
                read_avg_iops += float(tests[test_desc][vm_name]['read'][it]['iops'])
                read_avg_lat_min += float(tests[test_desc][vm_name]['read'][it]['latency_min'])
                read_avg_lat_mean += float(tests[test_desc][vm_name]['read'][it]['latency_mean'])
                read_avg_lat_dev += float(tests[test_desc][vm_name]['read'][it]['latency_dev'])
                read_avg_lat_max += float(tests[test_desc][vm_name]['read'][it]['latency_max'])

            read_avg_bandwidth /= 3
            read_avg_iops /= 3
            read_avg_lat_min /= 3
            read_avg_lat_max /= 3
            read_avg_lat_mean /= 3
            read_avg_lat_dev /= 3

            #print '\tiops:', avg_iops, '\tbandwidth:', avg_bandwidth, '\tlat_min:', avg_lat_min, '\tlat_max:', avg_lat_max, '\tlat_mean:', avg_lat_mean, '\tlat_dev:', avg_lat_dev


            #print '\t\t', 'write:', 

            write_avg_bandwidth = 0
            write_avg_iops = 0
            write_avg_lat_min = 0
            write_avg_lat_max = 0
            write_avg_lat_mean = 0
            write_avg_lat_dev = 0
            for it in tests[test_desc][vm_name]['write']:
                write_avg_bandwidth += float(tests[test_desc][vm_name]['write'][it]['bandwidth'])
                write_avg_iops += float(tests[test_desc][vm_name]['write'][it]['iops'])
                write_avg_lat_min += float(tests[test_desc][vm_name]['write'][it]['latency_min'])
                write_avg_lat_mean += float(tests[test_desc][vm_name]['write'][it]['latency_mean'])
                write_avg_lat_dev += float(tests[test_desc][vm_name]['write'][it]['latency_dev'])
                write_avg_lat_max += float(tests[test_desc][vm_name]['write'][it]['latency_max'])

            write_avg_bandwidth /= 3
            write_avg_iops /= 3
            write_avg_lat_min /= 3
            write_avg_lat_max /= 3
            write_avg_lat_mean /= 3
            write_avg_lat_dev /= 3

            #print '\tiops:', avg_iops, '\tbandwidth:', avg_bandwidth, '\tlat_min:', avg_lat_min, '\tlat_max:', avg_lat_max, '\tlat_mean:', avg_lat_mean, '\tlat_dev:', avg_lat_dev

            fout.write('%s,%s,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n' % (test_desc, 
                                                                                                     vm_name, 
                                                                                                     read_avg_iops, write_avg_iops, 
                                                                                                     read_avg_bandwidth, write_avg_bandwidth, 
                                                                                                     read_avg_lat_min, write_avg_lat_min,
                                                                                                     read_avg_lat_max, write_avg_lat_max,
                                                                                                     read_avg_lat_mean, write_avg_lat_mean,
                                                                                                     read_avg_lat_dev, write_avg_lat_dev))
            #fout.write('%s,%s,write,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n' % (test_desc, vm_name, avg_iops, avg_bandwidth, avg_lat_min, avg_lat_max, avg_lat_mean, avg_lat_dev))

    fout.close()


if __name__ == '__main__':
    args = build_arg_parser().parse_args()
    process_folder(args.directory, args.output)

