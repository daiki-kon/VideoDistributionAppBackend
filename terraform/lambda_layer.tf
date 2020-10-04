data "archive_file" "janome_lambda_layer" {
  type        = "zip"
  source_dir  = "terraform/modules/janome"
  output_path = "terraform/janome_lib.zip"
}

resource "aws_lambda_layer_version" "janome" {
  filename            = data.archive_file.janome_lambda_layer.output_path
  layer_name          = "janome"
  compatible_runtimes = ["python3.8"]
  source_code_hash    = data.archive_file.janome_lambda_layer.output_base64sha256
  depends_on          = [data.archive_file.janome_lambda_layer]
}

data "archive_file" "pytz_lambda_layer" {
  type        = "zip"
  source_dir  = "terraform/modules/pytz"
  output_path = "terraform/pytz_lib.zip"
}

resource "aws_lambda_layer_version" "pytz" {
  filename            = data.archive_file.pytz_lambda_layer.output_path
  layer_name          = "pytz"
  compatible_runtimes = ["python3.8"]
  source_code_hash    = data.archive_file.pytz_lambda_layer.output_base64sha256
  depends_on          = [data.archive_file.pytz_lambda_layer]
}