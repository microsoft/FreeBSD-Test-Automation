#!/usr/bin/env python

import wmi
import time

JOB_STATE_NEW       = 2
JOB_STATE_STARTING  = 3
JOB_STATE_RUNNING   = 4
JOB_STATE_SUSPENDED = 5
JOB_STATE_SHUTTINGDOWN  = 6
JOB_STATE_COMPLETED = 7
JOB_STATE_TERMINATED    = 8
JOB_STATE_KILLED    = 9
JOB_STATE_EXCEPTION = 10
JOB_STATE_SERVICE   = 11

def get_job(job_path):
    c = wmi.WMI(moniker=job_path)
    return c

def job_completed(job_path):
    job = get_job(job_path)
    while job.JobState == JOB_STATE_STARTING or job.JobState == JOB_STATE_RUNNING:
        print "Job in progress, ", str(job.PercentComplete) + "% completed."
        time.sleep(1)
        job = get_job(job_path)

    if job.JobState != JOB_STATE_COMPLETED:
        print "Job error:", job.ErrorCode, job.ErrorDescription
        return False
    return True


