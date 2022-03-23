# Maximiser
Eight-band maximiser based on IIR look-ahead peak limiters

This is an eight-band loudness maximiser based on IIR peak limiters and an
eight-way Linkwitz-Riley fourth-order crossover. The limiter deployes 
cascaded one-pole smoothers for minimal THD and the maximiser has two
maximisation modalities. 

On one hand, the maximiser offers the possibility to dynamically normalise the 
bands so that they have the same level approximately; on a sample-by-sample 
basis, the RMS of the loudest band is the reference value used to calculate a 
gain factor to bring all bands at the same level. The RMS calculation is 
carried out with 2πtau-constant one-pole filters and a one-second response 
time. Connected to this feature is a normalisation depth parameter that sets 
the maximum gain amount for normalisation. Assuming that the input signal 
without amplification is below 0 dB, the dynamical normalisation process does 
not set the limiters of the individual bands into an operational mode; hence, 
this process is free from degradation except for the limiting provided by the 
final limiter stage when the sum of the individual bands exceeds the ceiling. 
Alternatively, the maximisation can be performed by applying a gain 
amplification to the input signal, hence boosting all of the bands equally. 
The main difference is that dynamical normalisation provides maximum 
individual amplification with minimum degradation. On the other hand, the 
global gain amplification results in higher degradation for the predominant 
bands while keeping the overall spectral weights closer to the original 
signal.
