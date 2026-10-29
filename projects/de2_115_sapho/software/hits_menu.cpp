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
// Build: build.sh in this folder (YANC). Simulation: ../sim/hits_menu_tb.v.

#pragma yanc nuioou 9
#pragma yanc nuioin 3
#define YANC_LINK_SYNC 0
#include <iostream>
using namespace std;

// the longest orbit of the build, BUNCH_POS of hits (not in CAPS)
const int ORBIT_MAX = 3564;

// values written at the start
int occupancy = 65530;      // per 65536 filled crossings
int pedestal = 146;         // ADC counts
int mode = 2;               // bit 0: a hit on every filled crossing; bit 1: the bunch-train mask
int orbit = 3564;           // crossings per orbit
int phase0 = 0;             // 1/64 of the period
int sigma = 0;              // the jitter, as the constant K of the guide

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

void show()
{
    int caps = in(1);
    cout << endl << "HITS on SAPHO  ID " << hex << in(0) << "  CAPS " << caps << dec;
    if (in(2) & 1) cout << "  running" << endl;
    else           cout << "  stopped" << endl;
    cout << " 1 occupancy  " << occupancy << " / 65536" << endl;
    cout << " 2 pedestal   " << pedestal << " ADC" << endl;
    cout << " 3 mode       " << mode << " (1: every filled crossing, 2: mask)" << endl;
    cout << " 4 orbit      " << orbit << " crossings" << endl;
    if (caps & 12) {
        cout << " 5 phase0     " << phase0 << " / 64 of 25 ns" << endl;
        cout << " 6 sigma      " << sigma << endl;
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
        if (op == 1) {
            occupancy = read_int(0, 65535);
            out(3, occupancy);
        } else if (op == 2) {
            pedestal = read_int(-4096, 4095);
            out(4, pedestal);
        } else if (op == 3) {
            mode = read_int(0, 3);
            out(5, mode);
        } else if (op == 4) {
            orbit = read_int(1, ORBIT_MAX);
            running = in(2) & 1;
            out(2, 0);
            out(6, orbit);
            out(2, running);
        } else if (op == 5) {
            phase0 = read_int(-32, 31);
            out(7, phase0);
        } else if (op == 6) {
            sigma = read_int(0, 65535);
            out(8, sigma);
        } else if (op == 7) {
            running = in(2) & 1;
            out(2, 1 - running);
        } else {
            cout << "  options 1 to 7" << endl;
        }
    }
    return 0;
}
