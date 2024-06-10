1) You have to run this terraform script on a linux system.
2) You should have the AWS user with admin rights to create resources on AWS
3) You need to change:
	AWS Access key in variables.tfvars
	AWS secret key in variables.tfvars
	AWS region in variables.tfvars
	EC2 instance's size (Default size is t2.xlage, you may select any other instance type but it must have at least 4 CPUs)
4) Before running 'terraform apply', you will need to change the permission of private key file using command:
sudo chmod 400 strapikey.pem
5) When you execute the script, it will ask you the values of parameters like rds username and rds password, you have to provide the info as per your requirements.
6) After running this script successfully, you may SSH into your ec2 using the 'strapikey.pem' file.