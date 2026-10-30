"""make_stp.py -- writes stp1.stp, the Signal Tap of the DE2-115 project (issue #14).

Signal Tap captures the outputs of hits on the 40 MHz clock, 8192 crossings (more than
two orbits), from the first hit after the trigger is armed. The buses show as line
charts: the ADC samples, the shaped pulse, the noise and the energy as waveforms, the
way the simulation plots them.

The .stp is written here, not by the Signal Tap window, so it can be reviewed and made
again; Quartus compiles Signal Tap from the assignments of the .qsf, which

    quartus_stp hits_de2_115 --stp_file signaltap/stp1.stp --enable

writes from this file (run from projects/de2_115_sapho, after this script). The layout
of the XML is the one Quartus 23.1 wrote for projects/de10_nano_arm; "line_unsigned" and
"line_twos_complement" are the names Quartus 24.1 gives the formats Unsigned Line Chart
and Signed Line Chart.

    python signaltap/make_stp.py
"""
import os

DEPTH = 8192
CLOCK = "hits:sim|clk"
TRIGGER = "hits:sim|hits_out"          # rising edge

# (name, width, radix): radix None for a single wire
SIGNALS = [
    ("hits:sim|hits_out", 1, None),
    ("hits:sim|bt_mask_out", 1, None),
    ("hits:sim|energy_out", 13, "line_unsigned"),
    ("hits:sim|shaper_clip", 12, "line_unsigned"),        # the ADC samples
    ("hits:sim|noise_out", 17, "line_twos_complement"),
    ("hits:sim|shaper_out", 30, "line_twos_complement"),
]

DONT_CARE = ('pwr_level-0="dont_care" pwr_storage-0="dont_care" pwr_storage-1="dont_care" '
             'pwr_storage-2="dont_care" storage-0="dont_care" storage-1="dont_care" storage-2="dont_care"')
OR = 'storage-0="alt_or" storage-1="alt_or" storage-2="alt_or"'


def wires():
    out = []
    for name, width, _ in SIGNALS:
        out += [name] if width == 1 else [f"{name}[{b}]" for b in range(width)]
    return out


WIRES = wires()
INDEX = {w: i for i, w in enumerate(WIRES)}


def net(tag, w, indent):
    level = "rising edge" if w == TRIGGER else "dont_care"
    i = INDEX[w]
    return (f'{indent}<{tag} data_index="{i}" duplicate_name_allowed="false" is_data_input="true" '
            f'is_node_valid="true" is_selected="false" is_storage_input="true" is_trigger_input="true" '
            f'level-0="{level}" name="{w}" {DONT_CARE} storage_index="{i}" tap_mode="classic" '
            f'trigger_index="{i}" type="unknown"/>')


def view(tag, outer):
    lines = [f"        <{tag}>"]
    for name, width, radix in SIGNALS:
        if width == 1:
            lines.append(net(outer, name, "          "))
            continue
        lines.append(f'          <{"bus" if outer == "net" else "node"} is_selected="false" level-0="alt_or" '
                     f'name="{name}[{width - 1}..0]" order="msb_to_lsb" radix="{radix}" {OR} type="combinatorial">')
        for b in range(width - 1, -1, -1):
            lines.append(net(outer, f"{name}[{b}]", "            "))
        lines.append(f'          </{"bus" if outer == "net" else "node"}>')
    lines.append(f"        </{tag}>")
    return lines


def stp():
    ones = "1" * len(WIRES)
    L = ['<session jtag_chain="" jtag_device="" sof_file="output_files/hits_de2_115.sof">',
         '  <display_tree gui_logging_enabled="0">',
         '    <display_branch instance="auto_signaltap_0" signal_set="USE_GLOBAL_TEMP" trigger="USE_GLOBAL_TEMP"/>',
         '  </display_tree>',
         '  <instance enabled="true" entity_name="sld_signaltap" is_auto_node="yes" is_expanded="true" '
         'name="auto_signaltap_0" source_file="sld_signaltap.vhd">',
         '    <node_ip_info instance_id="0" mfg_id="110" node_id="0" version="6"/>',
         '    <signal_set global_temp="1" name="signal_set: hits outputs">',
         f'      <clock name="{CLOCK}" polarity="posedge" tap_mode="classic"/>',
         f'      <config pipeline_level="0" ram_type="AUTO" reserved_data_nodes="0" '
         f'reserved_storage_qualifier_nodes="0" reserved_trigger_nodes="0" sample_depth="{DEPTH}" '
         f'trigger_in_enable="no" trigger_out_enable="no"/>',
         '      <top_entity/>',
         '      <signal_vec>',
         '        <trigger_input_vec>']
    L += [f'          <wire name="{w}" tap_mode="classic"/>' for w in WIRES]
    L += ['        </trigger_input_vec>',
          '        <data_input_vec>']
    L += [f'          <wire name="{w}" tap_mode="classic"/>' for w in WIRES]
    L += ['        </data_input_vec>',
          '        <storage_qualifier_input_vec>']
    L += [f'          <wire name="{w}" tap_mode="classic"/>' for w in WIRES]
    L += ['        </storage_qualifier_input_vec>',
          '      </signal_vec>',
          '      <presentation>']
    L += view("unified_setup_data_view", "node")
    L += view("data_view", "net")
    L += view("setup_view", "net")
    L += ['        <trigger_in_editor/>',
          '        <trigger_out_editor/>',
          '      </presentation>',
          '      <trigger attribute_mem_mode="false" gap_record="true" global_temp="1" name="trigger: first hit" '
          'position="pre" power_up_trigger_mode="false" record_data_gap="true" segment_size="512" '
          'storage_mode="off" storage_qualifier_disabled="no" storage_qualifier_port_is_pin="false" '
          'storage_qualifier_port_name="auto_stp_external_storage_qualifier" '
          'storage_qualifier_port_tap_mode="classic" trigger_type="circular">',
          '        <power_up_trigger position="pre" storage_qualifier_disabled="no"/>',
          '        <events use_custom_flow_control="no">',
          f"          <level enabled=\"yes\" name=\"condition1\" type=\"basic\">'{TRIGGER}' == rising edge",
          '            <power_up enabled="yes">',
          '            </power_up>',
          '            <op_node/>',
          '          </level>',
          '        </events>',
          '        <storage_qualifier_events>',
          f'          <transitional>{ones}',
          f'            <pwr_up_transitional>{ones}</pwr_up_transitional>',
          '          </transitional>']
    for _ in range(3):
        L += ['          <storage_qualifier_level type="basic">',
              '            <power_up>',
              '            </power_up>',
              '            <op_node/>',
              '          </storage_qualifier_level>']
    L += ['        </storage_qualifier_events>',
          '      </trigger>',
          '    </signal_set>',
          '  </instance>',
          '  <mnemonics/>',
          '  <static_plugin_mnemonics/>',
          '  <global_info>',
          '    <single attribute="active instance" value="0"/>',
          '  </global_info>',
          '</session>']
    return "\n".join(L) + "\n"


if __name__ == "__main__":
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "stp1.stp")
    with open(path, "w", newline="\n") as f:
        f.write(stp())
    print(f"wrote {path}: {len(WIRES)} wires, {DEPTH} samples")
