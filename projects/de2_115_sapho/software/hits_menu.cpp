// hits_menu.cpp -- the configuration of HITS from a menu, on SAPHO, with a PS/2 keyboard
// and a VGA text screen (issue #14).
//
// SAPHO writes the registers of the configuration bus of hits through the adapter
// rtl/hits/hits_sapho.v: port p is register p, out(p, x) writes it and in(p) reads it
// (docs/guide/configuring.md). The keyboard (myKeyPS2, link 0) and the screen (myVGAText,
// link 1) are blocks of YANC on the 25 MHz pixel clock; SAPHO and hits run at 40 MHz, so
// the links are the ones that cross clocks (YANC_LINK_SYNC 0).
//
// The scalar registers are write-only: the program keeps a copy of each, writes them all
// at the start, so the screen and hits agree whatever the power-up values were, and
// writes one again when it changes. ORBIT_LEN is written with the simulation stopped, as
// the protocol asks. Integers only: no float operation, so SAPHO gets no float unit.
//
// A 16-bit SAPHO, the width of the bus: occupancy and sigma (0 to 65535) are unsigned,
// the others int. cin >> does not catch a number too big for the word (it wraps), so a
// value typed above 65535 is taken modulo 65536, and one out of the int range may wrap
// into the accepted range.
//
// Build: build.sh in this folder (YANC). Simulation: ../sim/hits_menu_tb.v.

#pragma yanc nuioou 9
#pragma yanc nuioin 3
#pragma yanc nubits 16
#define YANC_LINK_SYNC 0
#include <iostream>
using namespace std;

// the longest orbit of the build, BUNCH_POS of hits (not in CAPS)
const int ORBIT_MAX = 3564;

// values written at the start
unsigned occupancy = 65530;      // per 65536 filled crossings
int pedestal = 146;         // ADC counts
int mode = 2;               // bit 0: a hit on every crossing the mask lets through; bit 1: the mask
int orbit = 3564;           // crossings per orbit
int phase0 = 0;             // 1/64 of the period
unsigned sigma = 0;            // the jitter, as the constant K of the guide

void write_all()
{
    out(2, 0);              // stop: ORBIT_LEN only while stopped
    out(3, occupancy);
    out(4, pedestal);
    out(5, mode);
    out(6, orbit);
    out(7, phase0);
    out(8, sigma);
    out(2, 1);              // run, from the beginning
}

// reads an integer from lo to hi; asks again until it gets one
int read_int(int lo, int hi)
{
    int v;
    while (1) {
        cout << "  value (" << lo << " to " << hi << ")? ";
        cin >> v;
        if (cin.fail()) {
            cin.clear();
            v = lo - 1;
        }
        cin.ignore(100, '\n');
        if (v >= lo && v <= hi) return v;
        cout << "  out of range" << endl;
    }
}

// the same for the unsigned registers, from 0 to hi
unsigned read_uint(unsigned hi)
{
    unsigned v;
    int ok;
    while (1) {
        cout << "  value (0 to " << hi << ")? ";
        cin >> v;
        ok = !cin.fail();
        if (!ok) cin.clear();
        cin.ignore(100, '\n');
        if (ok && v <= hi) return v;
        cout << "  out of range" << endl;
    }
}

void show()
{
    int caps = in(1);
    cout << endl << "HITS on SAPHO  ID " << hex << in(0) << "  CAPS " << caps << dec;
    if (in(2) & 1) cout << "  running" << endl;
    else           cout << "  stopped" << endl;
    cout << " 1 occupancy  " << occupancy << " / 65536" << endl;
    cout << " 2 pedestal   " << pedestal << " ADC" << endl;
    cout << " 3 mode       " << mode << " (bit 0: a hit on every crossing, bit 1: the mask)" << endl;
    cout << " 4 orbit      " << orbit << " crossings" << endl;
    if (caps & 8) {             // PHASE0 and SIGMA act only with the jitter (CAPS bit 3)
        cout << " 5 phase0     " << phase0 << " / 64 of 25 ns" << endl;
        cout << " 6 sigma      " << sigma << " (K: 1 ns is 655)" << endl;
    }
    cout << " 7 run / stop" << endl;
}

int main()
{
    int op, running;
    write_all();
    while (1) {
        show();
        cout << "option? ";
        cin >> op;
        if (cin.fail()) {
            cin.clear();
            op = 0;
        }
        cin.ignore(100, '\n');
        // 5 and 6 only when the build has the jitter, as show() lists them
        if ((op == 5 || op == 6) && !(in(1) & 8)) op = 0;
        switch (op) {
        case 1:
            occupancy = read_uint(65535);
            out(3, occupancy);
            break;
        case 2:
            pedestal = read_int(-4096, 4095);
            out(4, pedestal);
            break;
        case 3:
            mode = read_int(0, 3);
            out(5, mode);
            break;
        case 4:
            orbit = read_int(1, ORBIT_MAX);
            running = in(2) & 1;
            out(2, 0);
            out(6, orbit);
            out(2, running);
            break;
        case 5:
            phase0 = read_int(-32, 31);
            out(7, phase0);
            break;
        case 6:
            sigma = read_uint(65535);
            out(8, sigma);
            break;
        case 7:
            running = in(2) & 1;
            out(2, 1 - running);
            break;
        default:
            cout << "  options 1 to 7" << endl;
        }
    }
    return 0;
}
