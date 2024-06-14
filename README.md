StressIO - stress test a mechanical hard drive by vomiting random data files, copying that vomit and          
comparing the results. This will test a drive's I/O stability, even if S.M.A.R.T does not report a            
fault. Using this, I have found bad drives that have passed all previous health checks.                       
                                                                                                              
Written by Nathaniel Berners.                                                                                 
                                                                                                              
WARNING - Using this script is destructive; make sure your data is backed up as it will be                    
irrecoverable afterwards! As such, this script comes with absolutely ZERO warranty:                           
DATA LOSS IS GUARANTEED!                                                                                      
                                                                                                               
To run StressIO, do as root:                                                                                  
stressio.sh /dev/<device>                                                                                     
where <device> is the drive identifier (such as sda, not an individual partion, such as sda1) 
