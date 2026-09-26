package eldersouls.cache;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import com.alex.store.Store;

public final class CacheInject {
    private CacheInject() {}

    private static String normalize(String cacheDir) {
        if (!cacheDir.endsWith("/") && !cacheDir.endsWith("\\")) {
            cacheDir += System.getProperty("file.separator");
        }
        return cacheDir;
    }

    private static Store open(String cacheDir) throws Exception {
        return new Store(normalize(cacheDir));
    }

    private static void put(String cacheDir, int index, int archive, int file, Path dataFile) throws Exception {
        Store store = open(cacheDir);
        if (index < 0 || index >= store.getIndexes().length || store.getIndexes()[index] == null)
            throw new IllegalArgumentException("Cache index " + index + " is unavailable.");
        byte[] data = Files.readAllBytes(dataFile);
        if (!store.getIndexes()[index].putFile(archive, file, data))
            throw new IllegalStateException("Index.putFile returned false.");
        System.out.println("OK put index=" + index + " archive=" + archive + " file=" + file + " bytes=" + data.length);
    }

    private static void read(String cacheDir, int index, int archive, int file, Path out) throws Exception {
        Store store = open(cacheDir);
        byte[] data = store.getIndexes()[index].getFile(archive, file);
        if (data == null)
            throw new IllegalArgumentException("No cache file at index=" + index + " archive=" + archive + " file=" + file);
        Files.write(out, data);
        System.out.println("OK read index=" + index + " archive=" + archive + " file=" + file + " bytes=" + data.length);
    }

    private static void cloneFile(String cacheDir, int index, int srcArchive, int srcFile, int dstArchive, int dstFile) throws Exception {
        Store store = open(cacheDir);
        byte[] data = store.getIndexes()[index].getFile(srcArchive, srcFile);
        if (data == null)
            throw new IllegalArgumentException("Source cache file does not exist.");
        if (!store.getIndexes()[index].putFile(dstArchive, dstFile, data))
            throw new IllegalStateException("Index.putFile returned false.");
        System.out.println("OK clone index=" + index + " " + srcArchive + ":" + srcFile + " -> " + dstArchive + ":" + dstFile);
    }

    private static void last(String cacheDir, int index) throws Exception {
        Store store = open(cacheDir);
        int archive = store.getIndexes()[index].getLastArchiveId();
        int file = archive >= 0 ? store.getIndexes()[index].getLastFileId(archive) : -1;
        System.out.println(archive + "," + file);
    }

    private static final class Reader {
        final byte[] data;
        int p;
        Reader(byte[] data) { this.data = data; }
        int u8() { return data[p++] & 0xff; }
        int s8() { return data[p++]; }
        int u16() { return (u8() << 8) | u8(); }
        int i32() { return (u8() << 24) | (u8() << 16) | (u8() << 8) | u8(); }
        int medium() { return (u8() << 16) | (u8() << 8) | u8(); }
        int bigSmart() {
            if ((data[p] & 0x80) != 0) return i32() & 0x7fffffff;
            return u16();
        }
        String str() {
            int start = p;
            while (p < data.length && data[p] != 0) p++;
            String s = new String(data, start, p - start, StandardCharsets.ISO_8859_1);
            if (p < data.length) p++;
            return s;
        }
    }

    private static final class ItemDef {
        int id;
        String name = "null";
        int modelId = 0;
        int modelZoom = 2000;
        int rotationX = 0;
        int rotationY = 0;
        int offsetX = 0;
        int offsetY = 0;
        int yaw = 0;
        int value = 1;
        int equipSlot = -1;
        int equipType = -1;
        boolean stackable;
        boolean members;
        boolean tradeable;
        int male1 = -1, male2 = -1, male3 = -1;
        int female1 = -1, female2 = -1, female3 = -1;
        int maleHead1 = -1, maleHead2 = -1, femaleHead1 = -1, femaleHead2 = -1;
        int scaleX = 128, scaleY = 128, scaleZ = 128;
        int shadow = 0, lightness = 0, team = 0;
        final String[] ground = new String[5];
        final String[] inventory = new String[5];
        final List<Integer> recolorFrom = new ArrayList<Integer>();
        final List<Integer> recolorTo = new ArrayList<Integer>();
        final List<Integer> retextureFrom = new ArrayList<Integer>();
        final List<Integer> retextureTo = new ArrayList<Integer>();
        final Map<Integer,Object> params = new LinkedHashMap<Integer,Object>();
    }

    private static void skipItemOpcode(Reader r, int opcode) {
        if (opcode == 18 || opcode == 94 || opcode == 97 || opcode == 98 || opcode == 121 || opcode == 122
                || opcode == 139 || opcode == 140 || (opcode >= 142 && opcode < 147)
                || (opcode >= 150 && opcode < 155) || opcode == 161 || opcode == 162 || opcode == 163) {
            r.u16();
        } else if (opcode == 27 || opcode == 96 || opcode == 115 || opcode == 134) {
            r.u8();
        } else if (opcode >= 100 && opcode < 110) {
            r.u16(); r.u16();
        } else if (opcode == 125 || opcode == 126) {
            r.s8(); r.s8(); r.s8();
        } else if (opcode >= 127 && opcode <= 130) {
            r.u8(); r.u16();
        } else if (opcode == 132) {
            int n = r.u8(); for (int i=0;i<n;i++) r.u16();
        } else if (opcode == 164) {
            r.str();
        } else if (opcode >= 242 && opcode <= 248) {
            r.bigSmart();
        } else if (opcode == 251 || opcode == 252) {
            int n = r.u8(); for (int i=0;i<n;i++) { r.u16(); r.u16(); }
        } else if (opcode == 42) {
            int n=r.u8(); for(int i=0;i<n;i++) r.s8();
        } else if (opcode == 44 || opcode == 45) {
            r.u16();
        } else if (opcode == 156 || opcode == 157 || opcode == 165) {
            // flag only
        } else {
            throw new IllegalArgumentException("Unsupported item opcode " + opcode);
        }
    }

    private static ItemDef decodeItem(int id, byte[] data) {
        ItemDef d = new ItemDef();
        d.id = id;
        if (data == null) return d;
        Reader r = new Reader(data);
        try {
            while (r.p < data.length) {
                int op = r.u8();
                if (op == 0) break;
                switch (op) {
                    case 1: d.modelId = r.bigSmart(); break;
                    case 2: d.name = r.str(); break;
                    case 4: d.modelZoom = r.u16(); break;
                    case 5: d.rotationX = r.u16(); break;
                    case 6: d.rotationY = r.u16(); break;
                    case 7: { int v=r.u16(); d.offsetX=v>32767?v-65536:v; break; }
                    case 8: { int v=r.u16(); d.offsetY=v>32767?v-65536:v; break; }
                    case 11: d.stackable = true; break;
                    case 12: d.value = r.i32(); break;
                    case 13: d.equipSlot = r.u8(); break;
                    case 14: d.equipType = r.u8(); break;
                    case 16: d.members = true; break;
                    case 23: d.male1 = r.bigSmart(); break;
                    case 24: d.male2 = r.bigSmart(); break;
                    case 25: d.female1 = r.bigSmart(); break;
                    case 26: d.female2 = r.bigSmart(); break;
                    case 65: d.tradeable = true; break;
                    case 78: d.male3 = r.bigSmart(); break;
                    case 79: d.female3 = r.bigSmart(); break;
                    case 90: d.maleHead1 = r.bigSmart(); break;
                    case 91: d.femaleHead1 = r.bigSmart(); break;
                    case 92: d.maleHead2 = r.bigSmart(); break;
                    case 93: d.femaleHead2 = r.bigSmart(); break;
                    case 95: d.yaw = r.u16(); break;
                    case 110: d.scaleX = r.u16(); break;
                    case 111: d.scaleY = r.u16(); break;
                    case 112: d.scaleZ = r.u16(); break;
                    case 113: d.shadow = r.s8(); break;
                    case 114: d.lightness = r.s8() * 5; break;
                    case 115: d.team = r.u8(); break;
                    case 40: {
                        int n=r.u8();
                        for(int i=0;i<n;i++){ d.recolorFrom.add(r.u16()); d.recolorTo.add(r.u16()); }
                        break;
                    }
                    case 41: {
                        int n=r.u8();
                        for(int i=0;i<n;i++){ d.retextureFrom.add(r.u16()); d.retextureTo.add(r.u16()); }
                        break;
                    }
                    case 249: {
                        int n=r.u8();
                        for(int i=0;i<n;i++){
                            boolean isString=r.u8()==1;
                            int key=r.medium();
                            d.params.put(key, isString ? r.str() : Integer.valueOf(r.i32()));
                        }
                        break;
                    }
                    default:
                        if (op >= 30 && op < 35) d.ground[op-30] = r.str();
                        else if (op >= 35 && op < 40) d.inventory[op-35] = r.str();
                        else skipItemOpcode(r, op);
                }
            }
        } catch (Exception ex) {
            // Return every field successfully decoded before an unfamiliar/truncated opcode.
        }
        return d;
    }

    private static String esc(String s) {
        if (s == null) return "";
        return s.replace("\\","\\\\").replace(""","\\\"").replace("\r","\\r").replace("\n","\\n").replace("\t","\\t");
    }

    private static String arr(String[] values) {
        StringBuilder b=new StringBuilder("[");
        for(int i=0;i<values.length;i++){
            if(i>0)b.append(',');
            if(values[i]==null)b.append("null"); else b.append('"').append(esc(values[i])).append('"');
        }
        return b.append(']').toString();
    }

    private static String ints(List<Integer> values) {
        StringBuilder b=new StringBuilder("[");
        for(int i=0;i<values.size();i++){ if(i>0)b.append(','); b.append(values.get(i)); }
        return b.append(']').toString();
    }

    private static String params(Map<Integer,Object> values) {
        StringBuilder b=new StringBuilder("{");
        boolean first=true;
        for(Map.Entry<Integer,Object> e:values.entrySet()){
            if(!first)b.append(',');
            first=false;
            b.append('"').append(e.getKey()).append("\":");
            if(e.getValue() instanceof String)b.append('"').append(esc((String)e.getValue())).append('"');
            else b.append(String.valueOf(e.getValue()));
        }
        return b.append('}').toString();
    }

    private static String itemJson(ItemDef d) {
        return "{"
            + "\"base_id\":"+d.id
            + ",\"model_id\":"+d.modelId
            + ",\"model_zoom\":"+d.modelZoom
            + ",\"rotation_x\":"+d.rotationX
            + ",\"rotation_y\":"+d.rotationY
            + ",\"offset_x\":"+d.offsetX
            + ",\"offset_y\":"+d.offsetY
            + ",\"yaw\":"+d.yaw
            + ",\"value\":"+d.value
            + ",\"stackable\":"+d.stackable
            + ",\"members\":"+d.members
            + ",\"tradeable\":"+d.tradeable
            + ",\"equip_slot\":"+d.equipSlot
            + ",\"equip_type\":"+d.equipType
            + ",\"male_model_1\":"+d.male1
            + ",\"male_model_2\":"+d.male2
            + ",\"male_model_3\":"+d.male3
            + ",\"female_model_1\":"+d.female1
            + ",\"female_model_2\":"+d.female2
            + ",\"female_model_3\":"+d.female3
            + ",\"male_head_model_1\":"+d.maleHead1
            + ",\"male_head_model_2\":"+d.maleHead2
            + ",\"female_head_model_1\":"+d.femaleHead1
            + ",\"female_head_model_2\":"+d.femaleHead2
            + ",\"scale_x\":"+d.scaleX
            + ",\"scale_y\":"+d.scaleY
            + ",\"scale_z\":"+d.scaleZ
            + ",\"shadow\":"+d.shadow
            + ",\"lightness\":"+d.lightness
            + ",\"team\":"+d.team
            + ",\"ground_options\":"+arr(d.ground)
            + ",\"inventory_options\":"+arr(d.inventory)
            + ",\"recolor_from\":"+ints(d.recolorFrom)
            + ",\"recolor_to\":"+ints(d.recolorTo)
            + ",\"retexture_from\":"+ints(d.retextureFrom)
            + ",\"retexture_to\":"+ints(d.retextureTo)
            + ",\"client_script_data\":"+params(d.params)
            + "}";
    }

    private static void itemIndex(String cacheDir) throws Exception {
        Store store=open(cacheDir);
        int index=19;
        int lastArchive=store.getIndexes()[index].getLastArchiveId();
        for(int archive=0;archive<=lastArchive;archive++){
            int lastFile;
            try { lastFile=store.getIndexes()[index].getLastFileId(archive); }
            catch(Exception e){ continue; }
            for(int file=0;file<=lastFile;file++){
                byte[] data=store.getIndexes()[index].getFile(archive,file);
                if(data==null)continue;
                int id=(archive<<8)|file;
                ItemDef d=decodeItem(id,data);
                if(d.name!=null && d.name.length()>0 && !"null".equalsIgnoreCase(d.name))
                    System.out.println(id+"\t"+d.name.replace("\t"," ").replace("\r"," ").replace("\n"," "));
            }
        }
    }

    private static void itemJson(String cacheDir,int id) throws Exception {
        Store store=open(cacheDir);
        byte[] data=store.getIndexes()[19].getFile(id>>>8,id&0xff);
        if(data==null)throw new IllegalArgumentException("No item definition for id "+id);
        ItemDef d=decodeItem(id,data);
        System.out.println("{\"id\":"+id+",\"name\":\""+esc(d.name)+"\",\"game_data\":"+itemJson(d)+"}");
    }

    public static void main(String[] args) throws Exception {
        if (args.length == 5 && !args[0].equals("put") && !args[0].equals("read")) {
            put(args[0], Integer.parseInt(args[1]), Integer.parseInt(args[2]), Integer.parseInt(args[3]), Paths.get(args[4]));
            return;
        }
        if (args.length < 1) throw new IllegalArgumentException("Missing command.");

        String cmd = args[0].toLowerCase();
        if ("put".equals(cmd) && args.length == 6) {
            put(args[1], Integer.parseInt(args[2]), Integer.parseInt(args[3]), Integer.parseInt(args[4]), Paths.get(args[5]));
        } else if ("read".equals(cmd) && args.length == 6) {
            read(args[1], Integer.parseInt(args[2]), Integer.parseInt(args[3]), Integer.parseInt(args[4]), Paths.get(args[5]));
        } else if ("clone".equals(cmd) && args.length == 7) {
            cloneFile(args[1], Integer.parseInt(args[2]), Integer.parseInt(args[3]), Integer.parseInt(args[4]),
                    Integer.parseInt(args[5]), Integer.parseInt(args[6]));
        } else if ("last".equals(cmd) && args.length == 3) {
            last(args[1], Integer.parseInt(args[2]));
        } else if ("itemindex".equals(cmd) && args.length == 2) {
            itemIndex(args[1]);
        } else if ("itemjson".equals(cmd) && args.length == 3) {
            itemJson(args[1], Integer.parseInt(args[2]));
        } else {
            throw new IllegalArgumentException(
                "Usage: put/read/clone/last/itemindex/itemjson");
        }
    }
}
