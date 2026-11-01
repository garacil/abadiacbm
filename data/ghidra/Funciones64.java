/*
 * abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
 *
 * Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
 * Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
 * implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not, see
 * <https://www.gnu.org/licenses/>.
 */

// Ghidra script for the CPC 64 KiB game (Z80): disassembles from the executed addresses of the
// exploration sessions, creates the functions of the map with their names (the full game's PC names
// where known) and a plate comment (PC address, CPC 6128 address, times called).
//   args: funciones64.tsv cobertura.txt
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSpace;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.SourceType;
import java.nio.file.Files;
import java.nio.file.Paths;

public class Funciones64 extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] a = getScriptArgs();
        AddressSpace sp = currentProgram.getAddressFactory().getDefaultAddressSpace();
        int seeds = 0, made = 0;
        for (String l : Files.readAllLines(Paths.get(a[1]))) {
            l = l.trim();
            if (l.isEmpty()) continue;
            Address ad = sp.getAddress(Long.parseLong(l, 16));
            if (getInstructionAt(ad) == null && getDataAt(ad) == null) { disassemble(ad); seeds++; }
        }
        for (String l : Files.readAllLines(Paths.get(a[0]))) {
            if (l.startsWith("#") || l.startsWith("addr64")) continue;
            String[] t = l.split("\t", -1);
            Address ad = sp.getAddress(Long.parseLong(t[0], 16));
            if (getInstructionAt(ad) == null) disassemble(ad);
            Function f = getFunctionAt(ad);
            try {
                if (f == null) { f = createFunction(ad, t[1]); }
                else f.setName(t[1], SourceType.USER_DEFINED);
            } catch (Exception e) { println("name " + t[1] + ": " + e.getMessage()); }
            if (f != null) made++;
            setPlateComment(ad, t[1] + " (64K " + t[0] + ")  PC " + (t[2].isEmpty() ? "-" : "1000:" + t[2])
                + "  CPC 6128 " + (t[3].isEmpty() ? "-" : t[3]) + "  called " + t[4] + " times in the exploration sessions");
        }
        println("Funciones64: " + seeds + " seeds disassembled, " + made + " functions");
    }
}
