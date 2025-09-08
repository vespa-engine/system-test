#!/usr/bin/env python3

from onnx import TensorProto
from onnx.helper import (
    make_model, make_node, make_graph,
    make_tensor_value_info)
from onnx.checker import check_model

X = make_tensor_value_info('model_input_1', TensorProto.FLOAT, ['cat', 2])
A = make_tensor_value_info('model_input_2', TensorProto.FLOAT, [2])
B = make_tensor_value_info('model_input_3', TensorProto.FLOAT, ['cat'])
Y = make_tensor_value_info('model_output_1', TensorProto.FLOAT, ['cat'])
Z = make_tensor_value_info('model_output_2', TensorProto.FLOAT, ['cat'])

node1 = make_node('MatMul', ['model_input_1', 'model_input_2'], ['XA'])
node2 = make_node('Add', ['XA', 'model_input_3'], ['model_output_1'])
node3 = make_node('MatMul', ['model_input_3', 'model_input_1'], ['model_output_2'])

graph = make_graph([node1, node2, node3], 'multiply_add', [X, A, B], [Y, Z])

onnx_model = make_model(graph)

# Generate older version
onnx_model.ir_version = 10
del onnx_model.opset_import[:]
opset = onnx_model.opset_import.add()
opset.version = 14

check_model(onnx_model)
with open("multiply_add.onnx", "wb") as f:
    f.write(onnx_model.SerializeToString())
print(onnx_model)
