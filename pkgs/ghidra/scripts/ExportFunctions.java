// Export every function to <dir>/functions.json, and the named ones (not FUN_xxxx) to
// <dir>/symbol_addrs.txt in splat's format. <dir> is the first script argument.
//@category Export
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Function;
import java.io.File;
import java.io.PrintWriter;

public class ExportFunctions extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        File dir = new File(args.length > 0 ? args[0] : ".");
        dir.mkdirs();
        int all = 0, named = 0;
        try (PrintWriter json = new PrintWriter(new File(dir, "functions.json"));
             PrintWriter syms = new PrintWriter(new File(dir, "symbol_addrs.txt"))) {
            json.println("[");
            for (Function f : currentProgram.getFunctionManager().getFunctions(true)) {
                long addr = f.getEntryPoint().getOffset();
                long size = f.getBody().getNumAddresses();
                String name = f.getName();
                json.printf("%s  {\"name\": \"%s\", \"addr\": \"0x%08X\", \"size\": %d, \"source\": \"%s\", \"signature\": \"%s\"}%n",
                    all == 0 ? " " : ",", esc(name), addr, size, f.getSymbol().getSource(), esc(f.getPrototypeString(false, false)));
                all++;
                if (!name.startsWith("FUN_")) {
                    syms.printf("%s = 0x%08X; // type:func size:0x%X%n", name, addr, size);
                    named++;
                }
            }
            json.println("]");
        }
        println("exported " + all + " functions (" + named + " named) to " + dir);
    }

    private static String esc(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
