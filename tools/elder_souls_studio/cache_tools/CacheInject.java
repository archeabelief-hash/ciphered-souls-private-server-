package eldersouls.cache;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
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

    public static void main(String[] args) throws Exception {
        // Backward compatible legacy form:
        // CacheInject <cacheDir> <index> <archive> <file> <dataFile>
        if (args.length == 5 && !args[0].equals("put") && !args[0].equals("read")) {
            put(args[0], Integer.parseInt(args[1]), Integer.parseInt(args[2]), Integer.parseInt(args[3]), Paths.get(args[4]));
            return;
        }
        if (args.length < 1)
            throw new IllegalArgumentException("Missing command.");

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
        } else {
            throw new IllegalArgumentException(
                "Usage: put <cacheDir> <index> <archive> <file> <dataFile> | " +
                "read <cacheDir> <index> <archive> <file> <outFile> | " +
                "clone <cacheDir> <index> <srcArchive> <srcFile> <dstArchive> <dstFile> | " +
                "last <cacheDir> <index>");
        }
    }
}
