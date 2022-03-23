/*******************************************************************************
**********      Eight-band loudness maximiser       ****************************
********************************************************************************
*
* This is an eight-band loudness maximiser based on IIR peak limiters and an
* eight-way Linkwitz-Riley fourth-order crossover. The limiter deployes 
* cascaded one-pole smoothers for minimal THD and the maximiser has two
* maximisation modalities. 
*
* On one hand, the maximiser offers the possibility to dynamically normalise the 
* bands so that they have the same level approximately; on a sample-by-sample 
* basis, the RMS of the loudest band is the reference value used to calculate a 
* gain factor to bring all bands at the same level. The RMS calculation is 
* carried out with 2πtau-constant one-pole filters and a one-second response 
* time. Connected to this feature is a normalisation depth parameter that sets 
* the maximum gain amount for normalisation. Assuming that the input signal 
* without amplification is below 0 dB, the dynamical normalisation process does 
* not set the limiters of the individual bands into an operational mode; hence, 
* this process is free from degradation except for the limiting provided by the 
* final limiter stage when the sum of the individual bands exceeds the ceiling. 
* Alternatively, the maximisation can be performed by applying a gain 
* amplification to the input signal, hence boosting all of the bands equally. 
* The main difference is that dynamical normalisation provides maximum 
* individual amplification with minimum degradation. On the other hand, the 
* global gain amplification results in higher degradation for the predominant 
* bands while keeping the overall spectral weights closer to the original 
* signal.
*
*******************************************************************************/

import("stdfaust.lib");
declare maximiserMono author "Dario Sanfilippo";
declare maximiserMono copyright
    "Copyright (C) 2022 Dario Sanfilippo <sanfilippo.dario@gmail.com>";
declare version "0.0";
declare maximiserMono license "MIT-style STK-4.3 license";
peakHold(t, x) = loop ~ _
    with {
        loop(fb) = ba.sAndH(cond1 | cond2, abs(x))
            with {
                cond1 = abs(x) >= fb;
                cond2 = loop ~ _ <: _ < _'
                    with {
                        loop(fb) = 
                            ((1 - cond1) * fb + (1 - cond1)) % (t * ma.SR + 1);
                    };
            };
    };
peakHoldCascade(N, holdTime, x) = x : seq(i, N, peakHold(holdTime / N));
smoother(N, att, rel, x) = loop ~ _
    with {
        loop(fb) = ba.if(abs(x) >= fb, attSection, relSection)
            with {
                attSection = attCoeff * fb + (1.0 - attCoeff) * abs(x);
                relSection = relCoeff * fb + (1.0 - relCoeff) * abs(x);
                attCoeff = 
                    exp((((-2.0 * ma.PI) / att) * cutoffCorrection) * ma.T);
                relCoeff = 
                    exp((((-2.0 * ma.PI) / rel) * cutoffCorrection) * ma.T);
                cutoffCorrection = 1.0 / sqrt(pow(2.0, 1.0 / N) - 1.0);
            };
    };
smootherCascade(N, att, rel, x) = x : seq(i, N, smoother(N, att, rel));
gainAttenuation(N, th, att, hold, rel, x) =  
    th / (max(th, peakHoldCascade(8, att + hold, x)) : 
        smootherCascade(N, att, rel));
limiterBand(centreFreq, th, att, hold, rel, preG, x_) = 
    de.sdelay(.1 * ma.SR, .02 * ma.SR, att * ma.SR, x) * gDisplay
    with {
        x = x_ * preG;
        g = gainAttenuation(4, th, att, hold, rel, x);
        gDisplay = attach(g, g : ba.linear2db : 
            vbargraph("h:Eight-Band Maximiser/h:Display/h:[00]Attenuation (dB)/%4centreFreq Hz", -60, 0));
    };
limiter4(th, att, hold, rel, preG, x_) = 
    de.sdelay(.1 * ma.SR, .02 * ma.SR, att * ma.SR, x) * g : peakDisplay
    with {
        x = x_ * preG;
        g = gainAttenuation(4, th, att, hold, rel, x);
        peakDisplay(x) = attach(x, peakHold(2.0, x) : ba.linear2db : 
            vbargraph("h:Eight-Band Maximiser/h:Display/h:[01]Peaks/[10]Peaks (dB)", -60, 0));
    };
crossover = bands , _ : fi.crossover8LR4
    with {
        bands = par(i, 7, 20 * 2 ^ (i + 2));
    };
dynamicNormalisation(N, depth) =   
    si.bus(N) <:
        si.bus(N) , 
        (par(i, N, an.rms_envelope_tau(1.0 / (2.0 * ma.PI))) <: 
            (maxN(N) <: si.bus(N)) , 
            si.bus(N) : ro.interleave(N, 2) : 
                par(i, N, /(max(ma.EPSILON))) : par(i, N, min(depth))) : 
                    ro.interleave(N, 2) : par(i, N, *)
    with {
        maxN(2) = max;
        maxN(N) = maxN(N - 1, max);
    };
maximiser8(x) = 
    x * bypass + (1.0 - bypass) * 
        (x : crossover : dynamicNormalisation(8, normDepth) : 
            par(band, 
                8, 
                limiterBand(ba.take(band + 1, centreFreq), 
                            1.0, 
                            att, 
                            hold, 
                            rel, 
                            preG)) :>
                    limiter4(th, att, hold, rel, 1.0))
    with {
        bypass = checkbox("h:Eight-Band Maximiser/v:Control/[009]Bypass") : 
            si.smoo;
        normDepth = 
            hslider("h:Eight-Band Maximiser/v:Control/[010]Normalisation Depth (dB)", .0, .0, 60.0, .000001) : 
            ba.db2linear : si.smoo;
        preG = 
            hslider("h:Eight-Band Maximiser/v:Control/[011]Pre Gain (dB)", 0., .0, 60.0, .000001) : 
            ba.db2linear : si.smoo;
        th = 
            hslider("h:Eight-Band Maximiser/v:Control/[012]Ceiling (dB)", -.3, -60.0, .0, .000001) : 
            ba.db2linear : si.smoo;
        att = 
            hslider("h:Eight-Band Maximiser/v:Control/[013]Attack (s)", .01, .001, .1, .000001) : 
            si.smoo;
        hold = 
            hslider("h:Eight-Band Maximiser/v:Control/[014]Hold (s)", .01, .0, 1.0, .000001) : 
            si.smoo;
        rel = 
            hslider("h:Eight-Band Maximiser/v:Control/[015]Release (s)", .1, .01, 1.0, .000001) : 
            si.smoo;
        centreFreq = par(i, 8, 30 * 2 ^ (i + 1));
    };
process = maximiser8;
