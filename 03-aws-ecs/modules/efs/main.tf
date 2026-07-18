resource "aws_security_group" "efs" {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    security_groups = [var.cluster_sg_id]
  }
}

resource "aws_efs_file_system" "efs" {
  creation_token = "efs"
}

resource "aws_efs_mount_target" "efs_mount" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = var.subnet_id
  security_groups = [aws_security_group.efs.id]
}