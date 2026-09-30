#!/usr/bin/env python3
"""HITS Launcher: janela com botoes Run (simulacao) e Waveform (surfer)."""

import os
import subprocess
import threading
import tkinter as tk
from tkinter import messagebox

import customtkinter as ctk

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("green")

BG = "#1a1a1a"
PANEL = "#242424"
LOG_BG = "#141414"
WAVE_BTN = "#3a3a3a"
WAVE_BTN_HOVER = "#4a4a4a"


class Launcher(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("HITS Launcher")
        self.geometry("560x480")
        self.minsize(480, 400)
        self.configure(fg_color=BG)

        ctk.CTkLabel(
            self, text="HITS: Hardware Impulse Train Synthesizer", font=ctk.CTkFont(size=20, weight="bold")
        ).pack(pady=(18, 4))

        occ_frame = ctk.CTkFrame(self, corner_radius=14, fg_color=PANEL)
        occ_frame.pack(fill="x", padx=20, pady=(6, 12))

        ctk.CTkLabel(
            occ_frame, text="Defina os valores da ocupação (0–127)", font=ctk.CTkFont(size=13, weight="bold")
        ).grid(row=0, column=0, columnspan=3, sticky="w", padx=(14, 4), pady=(12, 4))

        ctk.CTkButton(
            occ_frame, text="?", width=20, height=20, corner_radius=10,
            fg_color=WAVE_BTN, hover_color=WAVE_BTN_HOVER,
            font=ctk.CTkFont(size=12, weight="bold"),
            command=self.show_occupancy_help,
        ).grid(row=0, column=3, sticky="e", padx=(4, 14), pady=(12, 4))

        ctk.CTkLabel(occ_frame, text="Inicial").grid(row=1, column=0, sticky="e", padx=(14, 6), pady=(0, 14))
        self.occ_init = tk.StringVar(value="25")
        ctk.CTkEntry(occ_frame, width=64, textvariable=self.occ_init, corner_radius=10, justify="center").grid(
            row=1, column=1, pady=(0, 14)
        )

        ctk.CTkLabel(occ_frame, text="Final").grid(row=1, column=2, sticky="e", padx=(20, 6), pady=(0, 14))
        self.occ_step = tk.StringVar(value="80")
        ctk.CTkEntry(occ_frame, width=64, textvariable=self.occ_step, corner_radius=10, justify="center").grid(
            row=1, column=3, padx=(0, 14), pady=(0, 14)
        )

        btn_frame = ctk.CTkFrame(self, fg_color="transparent")
        btn_frame.pack(fill="x", padx=20, pady=(0, 12))

        self.run_btn = ctk.CTkButton(
            btn_frame, text="▶  Run", command=self.on_run, height=42, corner_radius=12,
            font=ctk.CTkFont(size=14, weight="bold"),
        )
        self.run_btn.pack(fill="x", pady=(0, 8))

        self.wave_btn = ctk.CTkButton(
            btn_frame, text="〜  Waveform", command=self.on_waveform, height=42, corner_radius=12,
            fg_color=WAVE_BTN, hover_color=WAVE_BTN_HOVER,
            font=ctk.CTkFont(size=14, weight="bold"),
        )
        self.wave_btn.pack(fill="x")

        self.log = ctk.CTkTextbox(
            self, corner_radius=14, fg_color=LOG_BG, text_color="#d0d0d0",
            font=ctk.CTkFont(family="Menlo", size=12), wrap="word",
        )
        self.log.pack(fill="both", expand=True, padx=20, pady=(0, 20))
        self.log.configure(state="disabled")

        self.protocol("WM_DELETE_WINDOW", self.destroy)

    def append_log(self, text):
        self.log.configure(state="normal")
        self.log.insert("end", text)
        self.log.see("end")
        self.log.configure(state="disabled")

    def show_occupancy_help(self):
        messagebox.showinfo(
            "Ocupação",
            "Fração de slots do bunch-train preenchidos com hits, em 127-avos "
            "(campo de 7 bits: 0 = vazio, 127 = todos os slots ocupados).\n\n"
            "Inicial: ocupação usada na primeira metade da simulação.\n"
            "Final: ocupação aplicada na segunda metade (degrau na metade do "
            "teste, padrão 25 → 80).",
        )

    def read_occupancy(self):
        try:
            occ_init = int(self.occ_init.get())
            occ_step = int(self.occ_step.get())
        except ValueError:
            messagebox.showerror("Ocupação inválida", "Os valores precisam ser números inteiros.")
            return None
        if not (0 <= occ_init <= 127) or not (0 <= occ_step <= 127):
            messagebox.showerror("Ocupação inválida", "Os valores precisam estar entre 0 e 127.")
            return None
        return occ_init, occ_step

    def on_run(self):
        occ = self.read_occupancy()
        if occ is None:
            return
        occ_init, occ_step = occ
        args = ["./run.sh", f"+OCC_INIT={occ_init}", f"+OCC_STEP={occ_step}"]
        self.run_btn.configure(state="disabled")
        self.append_log(f"\n$ {' '.join(args)}\n")
        threading.Thread(target=self.run_blocking, args=(args,), daemon=True).start()

    def run_blocking(self, args):
        try:
            proc = subprocess.Popen(
                args, cwd=SCRIPT_DIR, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, text=True,
            )
            for line in proc.stdout:
                self.after(0, self.append_log, line)
            proc.wait()
        except OSError as e:
            self.after(0, self.append_log, f"Erro ao rodar run.sh: {e}\n")
        finally:
            self.after(0, lambda: self.run_btn.configure(state="normal"))

    def on_waveform(self):
        try:
            subprocess.Popen(
                ["./waveform.sh"], cwd=SCRIPT_DIR,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            self.append_log("\n$ ./waveform.sh (em segundo plano)\n")
        except OSError as e:
            messagebox.showerror("Erro", f"Erro ao abrir waveform.sh: {e}")


if __name__ == "__main__":
    Launcher().mainloop()
