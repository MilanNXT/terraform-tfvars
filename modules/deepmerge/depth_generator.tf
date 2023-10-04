resource "local_file" "depth" {
    content     = templatefile("${path.module}/depth.tmpl", {max_depth = 15})
    filename = "${path.module}/depth.tf"
}