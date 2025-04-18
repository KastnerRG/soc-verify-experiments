from sklearn.model_selection import train_test_split
import numpy as np
import plotting
import subprocess

seed = 0

import tensorflow as tf

import os
import shutil
from tensorflow.keras.models import Sequential
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.regularizers import l1
from tensorflow.keras.initializers import RandomUniform
from qkeras.qlayers import QDense, QActivation
from qkeras.quantizers import quantized_bits, quantized_relu
import hls4ml

def HLS_run_single_layer(n_in, n_out, bits, int_bits, reuse_factor):
    os.environ['PATH'] += os.pathsep + '/tools/Xilinx/Vivado/2020.1/bin'
    np.random.seed(seed)
    tf.random.set_seed(seed)

    IN_SIZE = n_in
    OUT_SIZE = n_out
    N = 1024
    BITS = bits
    INT = int_bits
    REUSE_FACTOR = reuse_factor

    proj_name = 'dense_in%d_out%d_%d_%d_reuse_%d' % (IN_SIZE, OUT_SIZE, BITS, INT, REUSE_FACTOR) 
    output_dir = 'dense_prj/'+proj_name
    result_dir = 'dense_result/'+proj_name


    X = np.random.uniform(-2, 2, (N, IN_SIZE))
    True_W = np.random.uniform(-2, 2, (IN_SIZE, OUT_SIZE))
    Y = X @ True_W + np.random.normal(0, 0.05, (N, OUT_SIZE))
    X_train, X_test, Y_train, Y_test = train_test_split(X, Y, test_size=0.2, random_state=42)

    model = Sequential()
    model.add(
        QDense(
            OUT_SIZE,
            input_shape=(IN_SIZE,),
            name='fc1',
            kernel_quantizer=quantized_bits(BITS, INT, alpha=1),
            bias_quantizer=quantized_bits(BITS, INT, alpha=1),
            kernel_initializer='lecun_uniform',
            kernel_regularizer=l1(0.0001),
        )
    )
    model.add(QActivation(quantized_relu(BITS, INT), name='relu1'))    

    model.compile(optimizer=Adam(learning_rate=0.001), loss='mse')
    model.fit(
        X_train,
        Y_train,
        batch_size=256,
        epochs=10,
        validation_data=(X_test, Y_test),
        shuffle=True
    )

    config = hls4ml.utils.config_from_keras_model(model, granularity='Model', backend='VivadoAccelerator')
    config['Model']['ReuseFactor'] = REUSE_FACTOR
    config['Model']['Precision'] = 'ap_fixed<%d,%d>' % (BITS, INT)
    print("-----------------------------------")
    plotting.print_dict(config)
    print("-----------------------------------")

    hls_model = hls4ml.converters.convert_from_keras_model(
        model, 
        hls_config=config, 
        backend='VivadoAccelerator', 
        output_dir=output_dir, 
        board='zcu102',
        part='xczu9eg-ffvb1156-2-e',
        clock_period=4.5,
        io_type='io_stream',
        interface="axi_stream"
    )
    hls_model.compile()

    hls_model.build(csim=False, synth=True, vsynth=False, export=True)
    hls4ml.report.read_vivado_report(output_dir)

    # Copy the reports
    #if not os.path.exists(result_dir):
    #    os.makedirs(result_dir)

    #rtl_dir = './rtl'
    #if not os.path.exists(rtl_dir):
    #    os.makedirs(rtl_dir)
    
    #shutil.copy(output_dir+'/myproject_prj/solution1/syn/report/myproject_csynth.rpt', result_dir+'/'+proj_name+'_csynth.rpt')
    #shutil.copytree(output_dir+'/myproject_prj/solution1/impl/ip/hdl', rtl_dir+'/hdl')
    #shutil.copy(output_dir+'/vivado_synth.rpt', result_dir+'/'+proj_name+'_vsynth.rpt')        
    print("Model summary:")
    model.summary()
    return

def SIM_run_single_layer(batch, n_in, n_out, bits, int_bits, reuse_factor):
    os.environ['PATH'] += os.pathsep + '/tools/Xilinx/Vivado/2020.1/bin'
    BATCH = batch
    IN_SIZE = n_in
    OUT_SIZE = n_out
    N = 1024
    BITS = bits
    INT = int_bits
    REUSE_FACTOR = reuse_factor
    proj_name = 'dense_in%d_out%d_%d_%d_reuse_%d' % (IN_SIZE, OUT_SIZE, BITS, INT, REUSE_FACTOR) 
    output_dir = 'dense_prj/'+proj_name
    rtl_dir = './rtl'
    if not os.path.exists(rtl_dir):
        os.makedirs(rtl_dir)
    dst_dir = rtl_dir + '/hdl'
    if os.path.exists(dst_dir):
        shutil.rmtree(dst_dir)
    # Copy RTL files
    shutil.copytree(output_dir+'/myproject_prj/solution1/impl/ip/hdl', dst_dir)
    
    # Source files
    dirs = [
    './rtl/hdl/verilog',
    './rtl/ext',
    './rtl/sys',
    './tb/ext',
    './tb'
    ]
    dir_vhdl = ['./rtl/hdl/ip']

    # Base prefix to prepend to each printed path
    prefix = '../../'
    vlog_filelist = 'run/sources.txt'
    vhdl_filelist = 'run/sources_vhdl.txt'
    log_sim = f'{proj_name}_sim.log'
    profile_sim = f'{proj_name}_profile_sim.log'
    log_vivado = f'{proj_name}_vivado.log'
    profile_vivado = f'{proj_name}_profile_vivado.log'

    with open(vlog_filelist, 'w') as f:
        for d in dirs:
            for root, _, files in os.walk(d):
                for file in files:
                    full_path = os.path.join(root, file)
                    rel_path = os.path.relpath(full_path, start='.')  # relative to current dir
                    f.write(os.path.join(prefix, rel_path) + '\n')
    f.close()

    with open (vhdl_filelist, 'w') as f:
        for d in dir_vhdl:
            for root, _, files in os.walk(d):
                for file in files:
                    full_path = os.path.join(root, file)
                    rel_path = os.path.relpath(full_path, start='.')  # relative to current dir
                    f.write(os.path.join(prefix, rel_path) + '\n')
    f.close()

    # Build, C, RTL, elab & run simulation
    subprocess.run(['make', 'clean'], check=True)
    with open(log_sim, 'w') as log, open(profile_sim, 'w') as prof:
        subprocess.run([
            '/usr/bin/time', '-v',
            'make', 'all',
            f'B={BATCH}',
            f'I={IN_SIZE}',
            f'O={OUT_SIZE}'
            ],
            stdout=log, stderr=prof, check=True)
    
    # Run Vivado synth & impl
    with open(log_vivado, 'w') as log, open(profile_vivado, 'w') as prof:
        subprocess.run([
            '/usr/bin/time', '-v',
            'vivado', '-mode', 'batch',
            '-source', 'design.tcl'
            ],
            cwd=output_dir, stdout=log, stderr=prof, check=True)

    return

def HLS_run_jet_tagger(bits, int_bits, reuse_factor):
    os.environ['PATH'] += os.pathsep + '/tools/Xilinx/Vivado/2020.1/bin'
    np.random.seed(seed)
    tf.random.set_seed(seed)

    #IN_SIZE = n_in
    #OUT_SIZE = n_out
    N = 1024
    BITS = bits
    INT = int_bits
    REUSE_FACTOR = reuse_factor

    proj_name = 'jettagger_%d_%d_reuse_%d' % (BITS, INT, REUSE_FACTOR) 
    output_dir = 'jettagger_prj/'+proj_name
    result_dir = 'jettagger_result/'


    X = np.random.uniform(-2, 2, (N, 16))
    model = Sequential()
    model.add(
        QDense(
            64,
            input_shape=(16,),
            name='fc1',
            kernel_quantizer=quantized_bits(BITS, INT, alpha=1),
            bias_quantizer=quantized_bits(BITS, INT, alpha=1),
            kernel_initializer=RandomUniform(minval=-2.0, maxval=2.0),
            kernel_regularizer=l1(0.0001),
        )
    )
    model.add(QActivation(quantized_relu(BITS, INT), name='relu1')) 
    model.add(
        QDense(
            32,
            name='fc2',
            kernel_quantizer=quantized_bits(BITS, INT, alpha=1),
            bias_quantizer=quantized_bits(BITS, INT, alpha=1),
            kernel_initializer=RandomUniform(minval=-2.0, maxval=2.0),
            kernel_regularizer=l1(0.0001),
        )
    )
    model.add(QActivation(quantized_relu(BITS, INT), name='relu2'))
    model.add(
        QDense(
            32,
            name='fc3',
            kernel_quantizer=quantized_bits(BITS, INT, alpha=1),
            bias_quantizer=quantized_bits(BITS, INT, alpha=1),
            kernel_initializer=RandomUniform(minval=-2.0, maxval=2.0),
            kernel_regularizer=l1(0.0001),
        )
    )
    model.add(QActivation(quantized_relu(BITS, INT), name='relu3')) 
    model.add(
        QDense(
            5,
            name='fc4',
            kernel_quantizer=quantized_bits(BITS, INT, alpha=1),
            bias_quantizer=quantized_bits(BITS, INT, alpha=1),
            kernel_initializer=RandomUniform(minval=-2.0, maxval=2.0),
            kernel_regularizer=l1(0.0001),
        )
    )
    model.add(QActivation(quantized_relu(BITS, INT), name='relu4')) 



    model.compile(optimizer=Adam(learning_rate=0.001), loss='mse')
#    model.fit(
#        X_train,
#        Y_train,
#        batch_size=256,
#        epochs=10,
#        validation_data=(X_test, Y_test),
#        shuffle=True
#    )

    config = hls4ml.utils.config_from_keras_model(model, granularity='Model', backend='VivadoAccelerator')
    config['Model']['ReuseFactor'] = REUSE_FACTOR
    config['Model']['Precision'] = 'ap_fixed<%d,%d>' % (BITS, INT)
    print("-----------------------------------")
    plotting.print_dict(config)
    print("-----------------------------------")

    hls_model = hls4ml.converters.convert_from_keras_model(
        model, 
        hls_config=config, 
        backend='VivadoAccelerator', 
        output_dir=output_dir, 
        board='zcu102',
        part='xczu9eg-ffvb1156-2-e',
        clock_period=4.5,
        io_type='io_stream',
        interface="axi_stream"
    )
    hls_model.compile()

    hls_model.build(csim=False, synth=True, vsynth=False, export=True)
    hls4ml.report.read_vivado_report(output_dir)

    # Copy the reports
    if not os.path.exists(result_dir):
        os.makedirs(result_dir)

    rtl_dir = '../hls4ml-rtl/'+proj_name
    if not os.path.exists(rtl_dir):
        os.makedirs(rtl_dir)
    
    shutil.copy(output_dir+'/myproject_prj/solution1/syn/report/myproject_csynth.rpt', result_dir+'/'+proj_name+'_csynth.rpt')
    shutil.copytree(output_dir+'/myproject_prj/solution1/impl/ip/hdl', rtl_dir+'/hdl')
    #shutil.copy(output_dir+'/vivado_synth.rpt', result_dir+'/'+proj_name+'_vsynth.rpt')        

    return

def HLS_run_autoencoder(layers, width, bits, int_bits, reuse_factor):
    os.environ['PATH'] += os.pathsep + '/tools/Xilinx/Vitis_HLS/2024.1/bin'
    np.random.seed(seed)
    tf.random.set_seed(seed)

    #IN_SIZE = n_in
    #OUT_SIZE = n_out
    LAYERS = layers
    WIDTH = width
    N = 1024
    BITS = bits
    INT = int_bits
    REUSE_FACTOR = reuse_factor

    proj_name = 'autoencoder_%d_%d_%d_%d_reuse_%d' % (LAYERS, WIDTH, BITS, INT, REUSE_FACTOR) 
    output_dir = 'autoencoder_prj/' + proj_name
    result_dir = 'autoencoder_result/'


    X = np.random.uniform(-2, 2, (N, 16))
    model = Sequential()
    for i in range(LAYERS-1):
        model.add(
            QDense(
            WIDTH,
            input_shape=(WIDTH,),
            kernel_quantizer=quantized_bits(BITS, INT, alpha=1),
            bias_quantizer=quantized_bits(BITS, INT, alpha=1),
            kernel_initializer=RandomUniform(minval=-2.0, maxval=2.0),
            kernel_regularizer=l1(0.0001),
            )
        )
        model.add(QActivation(quantized_relu(BITS, INT))) 

    model.add(
        QDense(
            8,
            kernel_quantizer=quantized_bits(BITS, INT, alpha=1),
            bias_quantizer=quantized_bits(BITS, INT, alpha=1),
            kernel_initializer=RandomUniform(minval=-2.0, maxval=2.0),
            kernel_regularizer=l1(0.0001),
        )
    )
    model.add(QActivation(quantized_relu(BITS, INT)))
    model.add(
        QDense(
            8,
            kernel_quantizer=quantized_bits(BITS, INT, alpha=1),
            bias_quantizer=quantized_bits(BITS, INT, alpha=1),
            kernel_initializer=RandomUniform(minval=-2.0, maxval=2.0),
            kernel_regularizer=l1(0.0001),
        )
    )
    model.add(QActivation(quantized_relu(BITS, INT)))
    for i in range(LAYERS):
        model.add(
            QDense(
            WIDTH,
            input_shape=(WIDTH,),
            kernel_quantizer=quantized_bits(BITS, INT, alpha=1),
            bias_quantizer=quantized_bits(BITS, INT, alpha=1),
            kernel_initializer=RandomUniform(minval=-2.0, maxval=2.0),
            kernel_regularizer=l1(0.0001),
            )
        )
        model.add(QActivation(quantized_relu(BITS, INT))) 



    model.compile(optimizer=Adam(learning_rate=0.001), loss='mse')
#    model.fit(
#        X_train,
#        Y_train,
#        batch_size=256,
#        epochs=10,
#        validation_data=(X_test, Y_test),
#        shuffle=True
#    )

    config = hls4ml.utils.config_from_keras_model(model, granularity='Model', backend='Vitis')
    config['Model']['ReuseFactor'] = REUSE_FACTOR
    config['Model']['Precision'] = 'ap_fixed<%d,%d>' % (BITS, INT)
    print("-----------------------------------")
    plotting.print_dict(config)
    print("-----------------------------------")

    hls_model = hls4ml.converters.convert_from_keras_model(
        model, 
        hls_config=config, 
        backend='vitis', 
        output_dir=output_dir, 
        part='xczu9eg-ffvb1156-2-e',
        clock_period=4.5,
        io_type='io_stream',
        interface="axi_stream"
    )
    hls_model.compile()

    hls_model.build(csim=False, synth=True, vsynth=True)
    hls4ml.report.read_vivado_report(output_dir)

    # Copy the reports
    if not os.path.exists(result_dir):
        os.makedirs(result_dir)
    
    shutil.copy(output_dir+'/myproject_prj/solution1/syn/report/myproject_csynth.rpt', result_dir+'/'+proj_name+'_csynth.rpt')
    shutil.copy(output_dir+'/vivado_synth.rpt', result_dir+'/'+proj_name+'_vsynth.rpt')        

    return


