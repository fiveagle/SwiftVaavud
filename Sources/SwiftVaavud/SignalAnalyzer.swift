//
//  SignalAnalyzer.swift
//  VaavudSDK
//
//  Created by Marco Di Peco on 02/03/2020.
//  Copyright © 2020 Marco Di Peco. All rights reserved.
//

import Foundation
import Accelerate

@available(iOS 13.0, *)
public class SignalAnalyzer {
    
    let fftLength: Int
    let fftDataLength: Int
    let fftSetup: vDSP.FFT<DSPDoubleSplitComplex>
    var tempSplitComplex: DSPDoubleSplitComplex
    let scale: Double
    let nOver2: Int
    
    init?(fftLength: Int, fftDataLength: Int) {
        
        self.fftLength = fftLength
        self.fftDataLength = fftDataLength
        
        // log2(W), where W is the number of samples in the calculation window
        let log2n = UInt(floor(log2(Double(fftLength))))
        
        // Largest power of 2 that is less than W. The FFT is more performant when applied to windows with lengths equal to powers of 2.
        let nPowerOfTwo = Int(1 << log2n)
        
        // Dividing the largest power of 2 by 2. Once we get into computations on complex buffers it will make sense why this value is important.
        nOver2 = nPowerOfTwo / 2
        
        self.scale = 1.0 / Double(2 * nPowerOfTwo)
        
        // The Fast Fourier Transform results in complex values, z = x + iy, where z is a complex number, x and y are the real it’s real and imaginary components respectively, and i = sqrt(-1). For this implementation, we must create separate buffers for the real x and imaginary y components.
        var real = [Double](repeating: 0, count: nOver2)
        var imag = [Double](repeating: 0, count: nOver2)
        
        // A split complex buffer for storing real and imaginary components of complex numbers in the separate buffers defined above
        tempSplitComplex = DSPDoubleSplitComplex(realp: &real, imagp: &imag)
        
        //Here we define fftSetup, or precalculated data that is used by Accelerate to perform Fast Fourier Transforms. The parameters are the log of the max input size the setup can handle and the types of sizes the setup is compatible with respectively. In this case kFFTRadix2 denotes that our input’s size will be a power of 2.
        
        guard let fftSetup = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPDoubleSplitComplex.self) else {
            return nil
        }
        
        self.fftSetup = fftSetup
    }
    
    func perfomAnalysis(on data: [Double]) -> [Double] {
        
        // STEP 1 COPY DATA TO ioData, SUBTRACT MEAN, APPLY P. WELCH WINDOW, ZEROPAD
        var interleaved = data
        let ioDataMean: Double = Double(data.count / fftDataLength)
        
        for i in 0 ..< fftDataLength {
            interleaved[i] = (interleaved[i] - ioDataMean) * pWelchWindow(for: i)
        }
        
        for i in fftDataLength ..< fftLength {
            interleaved[i] = 0
        }
        
        // DO THE COMPUTATION
        
        /* Look at the real signal as an interleaved complex vector  by
         * casting it.  Then call the transformation function vDSP_ctoz to
         * get a split complex vector, which for a real signal, divides into
         * an even-odd configuration. */
        let groupedInterleaved = interleaved.chunked(into: 2)
        
        let complexInterleaved = groupedInterleaved.map { DSPDoubleComplex(real: $0[0], imag: $0[1]) }
        
        vDSP.convert(interleavedComplexVector: complexInterleaved, toSplitComplexVector: &tempSplitComplex)
        
        /* Carry out a Forward FFT transform. */
        fftSetup.transform(input: tempSplitComplex, output: &tempSplitComplex, direction: .forward)
        
        /* Scale it by 2n. */
        vDSP.multiply(tempSplitComplex, by: [scale], result: &tempSplitComplex)
        
        //Zero out the nyquist value
        tempSplitComplex.imagp[0] = 0.0
        
        // Calculate magnitude (vector distance)
        
        var distance = [Double](repeating: 0, count: nOver2)
        
        vDSP_vdistD(tempSplitComplex.realp, 1, tempSplitComplex.imagp, 1, &distance, 1, vDSP_Length(nOver2))
        
//        let reals = Array(UnsafeBufferPointer(start: tempSplitComplex.realp, count: nOver2))
//        let imag = Array(UnsafeBufferPointer(start: tempSplitComplex.imagp, count: nOver2))
//
//        vDSP.distanceSquared(reals, imag)
        
        // Scale again
        return vDSP.multiply(2, distance)
    }
    
    fileprivate func pWelchWindow(for i: Int) -> Double {
        
        let welch = 1 - ((i - (fftDataLength - 1) / 2) / ((fftDataLength + 1) / 2))^2
        
        return Double(welch)
    }
}
