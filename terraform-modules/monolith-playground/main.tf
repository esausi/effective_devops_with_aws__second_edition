resource "aws_instance" "playground" {
  ami           = "${var.my_ami_id}"
  instance_type = "t2.micro"
  user_data = <<EOF
#!/bin/bash
sudo amazon-linux-extras enable corretto8 ; sudo yum -y remove java-11-amazon-corretto-headless java-11-amazon-corretto ; sudo yum -y install java-1.8.0-amazon-corretto
#sudo yum -y install httpd mariadb.x86_64 mariadb-server
echo "<VirtualHost *>" > /etc/httpd/conf.d/tomcat-proxy.conf
echo "        ProxyPass               /visits      http://localhost:8080/visits" >> /etc/httpd/conf.d/tomcat-proxy.conf
echo "        ProxyPassReverse       /visits      http://localhost:8080/visits" >> /etc/httpd/conf.d/tomcat-proxy.conf
echo "</VirtualHost>" >> /etc/httpd/conf.d/tomcat-proxy.conf
#systemctl start mariadb
chkconfig httpd on
#chkconfig mariadb on
systemctl restart httpd
#mysql -u root -e "create database demodb;" -h demodb.cppfbbymwiar.us-east-1.rds.amazonaws.com
#mysql -u root -e "CREATE TABLE visits (id bigint(20) NOT NULL AUTO_INCREMENT, count bigint(20) NOT NULL, version bigint(20) NOT NULL, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=latin1;" demodb -h demodb.cppfbbymwiar.us-east-1.rds.amazonaws.com
#mysql -u root -e "INSERT INTO demodb.visits (count) values (0) ;"
#mysql -u root -e "CREATE USER 'monty'@'localhost' IDENTIFIED BY 'some_pass';"
#mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'monty'@'localhost' WITH GRANT OPTION;"
runuser -l ec2-user -c 'cd /home/ec2-user ; curl -O https://raw.githubusercontent.com/esausi/effective_devops_with_aws__second_edition/master/terraform-modules/monolith-playground/demo-0.0.1-SNAPSHOT.jar'
runuser -l ec2-user -c 'cd /home/ec2-user ; curl -O https://raw.githubusercontent.com/esausi/effective_devops_with_aws__second_edition/master/terraform-modules/monolith-playground/tomcat.sh'
cd /etc/systemd/system/ ; curl -O https://raw.githubusercontent.com/esausi/effective_devops_with_aws__second_edition/master/terraform-modules/monolith-playground/tomcat.service
chmod +x /home/ec2-user/tomcat.sh
systemctl enable tomcat.service
systemctl start tomcat.service
#Install EC2 Instance Connect for allow connections using any publickey
sudo yum -y install ec2-instance-connect
EOF
  vpc_security_group_ids = ["${aws_security_group.playground.id}"]
  subnet_id = "${var.my_subnet}"
  key_name  = "${var.my_pem_keyname}"
  tags = {
    Name = "Monolith Playground"
  }
}

resource "aws_security_group" "rds" {
  name = "allow_from_my_vpc"
  description = "Allow from my vpc"
  vpc_id = "${var.my_vpc_id}"

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["172.31.0.0/16"]
  }
}

module "db" {
  source = "terraform-aws-modules/rds/aws"
  identifier = "demodb"
  engine = "mysql"
  engine_version = "5.7.19"
  instance_class = "db.t2.micro"
  allocated_storage = 5
  name = "demodb"
  username = "monty"
  password = "some_pass"
  port = 3306

  vpc_security_group_ids = ["${aws_security_group.rds.id}"]
  # DB subnet group
  #subnet_ids = ["subnet-dp56b4ff", "subnet-b541edfe"]
  subnet_ids = ["subnet-6a0c9627", "subnet-67558238"]
  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window = "03:00-06:00"
  # DB parameter group
  family = "mysql5.7"
  # DB option group
  major_engine_version = "5.7"
}

resource "aws_security_group" "playground" {
  name        = "allow_all"
  description = "Allow all inbound traffic"
  vpc_id      = "${var.my_vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "playground" {
  vpc      = true
  instance = "${aws_instance.playground.id}"
}
