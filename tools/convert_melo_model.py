"""Convert the dynamic-INT8 MeloTTS ONNX model into a plain float model.

The source model runs every Conv/MatMul through ConvInteger/MatMulInteger with
DynamicQuantizeLinear, which ONNX Runtime's CPU provider executes slowly on iOS
(about 1.5x slower than real time). This script dequantizes the weights back to
float Conv/MatMul and stores large weights as FP16 with a Cast to float, which
ONNX Runtime folds into FP32 constants when the session loads.

Usage: python tools/convert_melo_model.py <melotts_kr_int8.onnx> <melotts_kr_fp16.onnx>
Requires: onnx, numpy
"""
import collections
import sys

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper


def dequantize(graph):
    inits = {i.name: i for i in graph.initializer}
    producer = {o: n for n in graph.node for o in n.output}
    consumers = collections.defaultdict(list)
    for node in graph.node:
        for name in node.input:
            consumers[name].append(node)

    def array(name):
        return numpy_helper.to_array(inits[name])

    removed, replaced, new_inits = set(), {}, []
    for node in graph.node:
        if node.op_type not in ("ConvInteger", "MatMulInteger"):
            continue
        quantize = producer[node.input[0]]
        assert quantize.op_type == "DynamicQuantizeLinear"
        (cast,) = consumers[node.output[0]]
        assert cast.op_type == "Cast"
        (scale_mul,) = consumers[cast.output[0]]
        assert scale_mul.op_type == "Mul"
        scales = producer[scale_mul.input[1]]
        assert scales.op_type == "Mul"
        (weight_scale,) = [name for name in scales.input if name in inits]

        weight = array(node.input[1]).astype(np.float32)
        zero_point = array(node.input[3]).astype(np.float32)
        scale = array(weight_scale).astype(np.float32)
        if node.op_type == "ConvInteger" and scale.size > 1:
            scale = scale.reshape((-1,) + (1,) * (weight.ndim - 1))
            zero_point = zero_point.reshape(scale.shape)
        weight_name = node.input[1].replace("_quantized", "") + "_float"
        new_inits.append(numpy_helper.from_array(((weight - zero_point) * scale).astype(np.float32), weight_name))

        op_type = "Conv" if node.op_type == "ConvInteger" else "MatMul"
        float_node = helper.make_node(op_type, [quantize.input[0], weight_name], [scale_mul.output[0]],
                                      name=node.name.replace("_quant", "_float"))
        if op_type == "Conv":
            float_node.attribute.extend(node.attribute)
        replaced[id(node)] = float_node
        removed.update({id(cast), id(scale_mul)})

    nodes = [replaced.get(id(n), n) for n in graph.node if id(n) not in removed]
    outputs = {o.name for o in graph.output}
    while True:
        used = outputs | {name for n in nodes for name in n.input}
        alive = [n for n in nodes if any(o in used for o in n.output)]
        if len(alive) == len(nodes):
            break
        nodes = alive
    used = {name for n in nodes for name in n.input}
    initializers = [i for i in list(graph.initializer) + new_inits if i.name in used]
    del graph.node[:]
    graph.node.extend(nodes)
    del graph.initializer[:]
    graph.initializer.extend(initializers)


def store_weights_as_fp16(graph):
    casts = []
    for init in graph.initializer:
        if init.data_type != TensorProto.FLOAT:
            continue
        values = numpy_helper.to_array(init)
        if values.size < 1024:
            continue
        name = init.name
        init.CopyFrom(numpy_helper.from_array(values.astype(np.float16), name + "_fp16"))
        casts.append(helper.make_node("Cast", [name + "_fp16"], [name], to=TensorProto.FLOAT, name=name + "_upcast"))
    nodes = casts + list(graph.node)
    del graph.node[:]
    graph.node.extend(nodes)


def main(source, destination):
    model = onnx.load(source)
    dequantize(model.graph)
    store_weights_as_fp16(model.graph)
    onnx.checker.check_model(model)
    onnx.save(model, destination)
    counts = collections.Counter(n.op_type for n in model.graph.node)
    print({op: counts[op] for op in ("Conv", "MatMul", "ConvInteger", "MatMulInteger", "DynamicQuantizeLinear")})


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
