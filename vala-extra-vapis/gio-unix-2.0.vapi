// Dummy vapi file for gio-unix to allow compilation without GIO Unix bindings
// Use GioOutputStream instead of UnixOutputStream when available

public abstract class Gio.OutputStream : GLib.BytesHandle {
    public Gio.OutputStream (InputStream is)
    
    public Gio.OutputStream (GIO.InputStream io, bool close_source = true)
}
