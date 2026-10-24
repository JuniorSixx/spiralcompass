// Spiral Compass — painel externo. Compila com o csc.exe do .NET Framework (C# 5), sem dependencias.
// Comunica com o mod Lua via cmd.txt (painel -> jogo) e state.txt (jogo -> painel).
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

static class Theme
{
    public static readonly Color Bg = Color.FromArgb(18, 18, 22);
    public static readonly Color Card = Color.FromArgb(28, 28, 34);
    public static readonly Color CardHi = Color.FromArgb(38, 38, 46);
    public static readonly Color Line = Color.FromArgb(48, 48, 58);
    public static readonly Color Fg = Color.FromArgb(232, 230, 228);
    public static readonly Color Dim = Color.FromArgb(140, 138, 148);
    public static readonly Color Faint = Color.FromArgb(90, 88, 100);
    public static readonly Color Accent = Color.FromArgb(200, 50, 70);
    public static readonly Color AccentHi = Color.FromArgb(226, 72, 92);
    public static readonly Color Teal = Color.FromArgb(110, 200, 196);
    public static readonly Color Gold = Color.FromArgb(240, 196, 110);
    public static readonly Color Blue = Color.FromArgb(130, 168, 220);
    public static readonly Color Violet = Color.FromArgb(178, 140, 235);
    public static readonly Color Green = Color.FromArgb(110, 200, 130);

    public static Font F(float size, FontStyle st) { return new Font("Segoe UI", size, st); }
    public static readonly Font Body = F(9.5f, FontStyle.Regular);
    public static readonly Font Small = F(8.5f, FontStyle.Regular);
    public static readonly Font Bold = F(9.5f, FontStyle.Bold);
    public static readonly Font Title = F(15f, FontStyle.Bold);
    public static readonly Font H2 = F(12f, FontStyle.Bold);
    public static readonly Font Caps = F(7.5f, FontStyle.Bold);

    public static GraphicsPath Round(RectangleF r, float rad)
    {
        GraphicsPath p = new GraphicsPath();
        float d = rad * 2;
        if (d > r.Height) d = r.Height;
        if (d > r.Width) d = r.Width;
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    public static void Smooth(Graphics g)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
    }

    [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr h, int attr, ref int val, int size);
    [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)] public static extern int SetWindowTheme(IntPtr h, string app, string id);

    public static void DarkTitle(Form f)
    {
        try
        {
            int on = 1;
            DwmSetWindowAttribute(f.Handle, 20, ref on, 4);           // modo escuro
            int cap = Bg.R | (Bg.G << 8) | (Bg.B << 16);
            DwmSetWindowAttribute(f.Handle, 35, ref cap, 4);          // cor da barra (Win11)
        }
        catch (Exception) { }
    }
}

// ---------------------------------------------------------------- controles desenhados
class Card : Panel
{
    public string Caption = "";
    public Color Stripe = Color.Empty;
    public Card()
    {
        DoubleBuffered = true;
        SetStyle(ControlStyles.ResizeRedraw | ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true);
        BackColor = Theme.Bg;
        Padding = new Padding(14, 30, 14, 12);
    }
    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        Theme.Smooth(g);
        RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
        using (GraphicsPath p = Theme.Round(r, 10))
        using (SolidBrush b = new SolidBrush(Theme.Card))
        using (Pen pen = new Pen(Theme.Line))
        {
            g.FillPath(b, p);
            g.DrawPath(pen, p);
        }
        if (Stripe != Color.Empty)
            using (SolidBrush sb = new SolidBrush(Stripe))
            using (GraphicsPath sp = Theme.Round(new RectangleF(0, 12, 4, Height - 24), 2))
                g.FillPath(sb, sp);
        if (Caption != "")
            using (SolidBrush tb = new SolidBrush(Theme.Faint))
                g.DrawString(Caption.ToUpperInvariant(), Theme.Caps, tb, 14, 10);
    }
}

class Toggle : Control
{
    bool on, hover;
    public event EventHandler CheckedChanged;
    public bool Checked { get { return on; } set { if (on != value) { on = value; Invalidate(); if (CheckedChanged != null) CheckedChanged(this, EventArgs.Empty); } } }
    public string Hint = "";
    public Toggle(string text)
    {
        Text = text;
        DoubleBuffered = true;
        SetStyle(ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Theme.Card;
        Cursor = Cursors.Hand;
        Size = new Size(240, 44);
    }
    protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); }
    protected override void OnMouseLeave(EventArgs e) { hover = false; Invalidate(); }
    protected override void OnClick(EventArgs e) { Checked = !Checked; }
    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        Theme.Smooth(g);
        RectangleF track = new RectangleF(2, (Height - 22) / 2f, 40, 22);
        using (GraphicsPath p = Theme.Round(track, 11))
        using (SolidBrush b = new SolidBrush(on ? Theme.Accent : (hover ? Theme.Line : Theme.CardHi)))
            g.FillPath(b, p);
        float kx = on ? track.Right - 19 : track.X + 3;
        using (SolidBrush k = new SolidBrush(on ? Color.White : Theme.Dim))
            g.FillEllipse(k, kx, track.Y + 3, 16, 16);
        using (SolidBrush tb = new SolidBrush(on ? Theme.Fg : Theme.Dim))
            g.DrawString(Text, Theme.Body, tb, 52, Hint == "" ? (Height - 18) / 2f : 3);
        if (Hint != "")
            using (SolidBrush hb = new SolidBrush(Theme.Faint))
                g.DrawString(Hint, Theme.Small, hb, 52, 22);
    }
}

class Slider : Control
{
    int min = 5, max = 50, val = 10;
    bool drag;
    public event EventHandler ValueChanged;
    public int Value { get { return val; } set { int v = Math.Max(min, Math.Min(max, value)); if (v != val) { val = v; Invalidate(); if (ValueChanged != null) ValueChanged(this, EventArgs.Empty); } } }
    public Slider() { DoubleBuffered = true; BackColor = Theme.Card; Cursor = Cursors.Hand; Height = 28; TabStop = true; }
    RectangleF Track { get { return new RectangleF(10, Height / 2f - 3, Width - 20, 6); } }
    void SetFromX(int x) { RectangleF t = Track; double f = (x - t.X) / t.Width; Value = (int)Math.Round(min + f * (max - min)); }
    protected override void OnMouseDown(MouseEventArgs e) { drag = true; Focus(); SetFromX(e.X); }
    protected override void OnMouseMove(MouseEventArgs e) { if (drag) SetFromX(e.X); }
    protected override void OnMouseUp(MouseEventArgs e) { drag = false; }
    protected override bool IsInputKey(Keys k) { return k == Keys.Left || k == Keys.Right || base.IsInputKey(k); }
    protected override void OnKeyDown(KeyEventArgs e) { if (e.KeyCode == Keys.Left) Value--; if (e.KeyCode == Keys.Right) Value++; }
    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        Theme.Smooth(g);
        RectangleF t = Track;
        float f = (val - min) / (float)(max - min);
        using (GraphicsPath p = Theme.Round(t, 3)) using (SolidBrush b = new SolidBrush(Theme.CardHi)) g.FillPath(b, p);
        using (GraphicsPath p = Theme.Round(new RectangleF(t.X, t.Y, Math.Max(6, t.Width * f), t.Height), 3))
        using (SolidBrush b = new SolidBrush(Theme.Accent)) g.FillPath(b, p);
        // marca do 1x
        float one = t.X + t.Width * (10 - min) / (float)(max - min);
        using (Pen pm = new Pen(Theme.Faint, 2)) g.DrawLine(pm, one, t.Bottom + 3, one, t.Bottom + 7);
        float kx = t.X + t.Width * f;
        using (SolidBrush k = new SolidBrush(Color.White)) g.FillEllipse(k, kx - 8, Height / 2f - 8, 16, 16);
        using (Pen kp = new Pen(Theme.Accent, 2)) g.DrawEllipse(kp, kx - 8, Height / 2f - 8, 16, 16);
    }
}

class StatBar : Control
{
    public string Label = "";
    public double Val, Max = 1;
    public Color Fill = Theme.Accent;
    public StatBar() { DoubleBuffered = true; BackColor = Theme.Card; Height = 34; }
    public void Set(double v, double m) { if (v != Val || m != Max) { Val = v; Max = m <= 0 ? 1 : m; Invalidate(); } }
    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        Theme.Smooth(g);
        using (SolidBrush tb = new SolidBrush(Theme.Dim)) g.DrawString(Label, Theme.Small, tb, 0, 0);
        string num = Math.Round(Val).ToString(CultureInfo.InvariantCulture) + " / " + Math.Round(Max).ToString(CultureInfo.InvariantCulture);
        SizeF ns = g.MeasureString(num, Theme.Small);
        using (SolidBrush nb = new SolidBrush(Theme.Fg)) g.DrawString(num, Theme.Small, nb, Width - ns.Width, 0);
        RectangleF t = new RectangleF(0, 22, Width - 1, 6);
        using (GraphicsPath p = Theme.Round(t, 3)) using (SolidBrush b = new SolidBrush(Theme.CardHi)) g.FillPath(b, p);
        float f = (float)Math.Max(0, Math.Min(1, Val / Max));
        if (f > 0)
            using (GraphicsPath p = Theme.Round(new RectangleF(t.X, t.Y, Math.Max(6, t.Width * f), t.Height), 3))
            using (SolidBrush b = new SolidBrush(Fill)) g.FillPath(b, p);
    }
}

class FlatButton : Control
{
    bool hover, down;
    public Color Fill = Theme.Accent;
    public bool Ghost;
    public FlatButton(string text) { Text = text; DoubleBuffered = true; Cursor = Cursors.Hand; Height = 36; BackColor = Theme.Card; }
    protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); }
    protected override void OnMouseLeave(EventArgs e) { hover = false; down = false; Invalidate(); }
    protected override void OnMouseDown(MouseEventArgs e) { down = true; Invalidate(); }
    protected override void OnMouseUp(MouseEventArgs e) { down = false; Invalidate(); }
    protected override void OnEnabledChanged(EventArgs e) { Cursor = Enabled ? Cursors.Hand : Cursors.Default; Invalidate(); }
    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        Theme.Smooth(g);
        RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
        Color c = !Enabled ? Theme.CardHi : (Ghost ? (hover ? Theme.CardHi : Theme.Card) : (down ? ControlPaint.Dark(Fill, 0.1f) : (hover ? ControlPaint.Light(Fill, 0.15f) : Fill)));
        using (GraphicsPath p = Theme.Round(r, 8))
        {
            using (SolidBrush b = new SolidBrush(c)) g.FillPath(b, p);
            if (Ghost || !Enabled) using (Pen pen = new Pen(Theme.Line)) g.DrawPath(pen, p);
        }
        Color tc = !Enabled ? Theme.Faint : (Ghost ? Theme.Fg : Color.White);
        TextRenderer.DrawText(g, Text, Theme.Bold, Rectangle.Round(r), tc, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
    }
}

class Tabs : Control
{
    public string[] Items = new string[0];
    int sel, hover = -1;
    public event EventHandler SelectedChanged;
    public int Selected { get { return sel; } set { if (sel != value) { sel = value; Invalidate(); if (SelectedChanged != null) SelectedChanged(this, EventArgs.Empty); } } }
    public Tabs() { DoubleBuffered = true; Height = 38; BackColor = Theme.Bg; Cursor = Cursors.Hand; }
    int HitTest(int x) { return Items.Length == 0 ? -1 : Math.Min(Items.Length - 1, x * Items.Length / Math.Max(1, Width)); }
    protected override void OnMouseMove(MouseEventArgs e) { int h = HitTest(e.X); if (h != hover) { hover = h; Invalidate(); } }
    protected override void OnMouseLeave(EventArgs e) { hover = -1; Invalidate(); }
    protected override void OnMouseDown(MouseEventArgs e) { Selected = HitTest(e.X); }
    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        Theme.Smooth(g);
        RectangleF all = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
        using (GraphicsPath p = Theme.Round(all, 10)) using (SolidBrush b = new SolidBrush(Theme.Card)) g.FillPath(b, p);
        float w = (Width - 8) / (float)Math.Max(1, Items.Length);
        for (int i = 0; i < Items.Length; i++)
        {
            RectangleF r = new RectangleF(4 + i * w, 4, w - 2, Height - 8);
            if (i == sel || i == hover)
                using (GraphicsPath p = Theme.Round(r, 7))
                using (SolidBrush b = new SolidBrush(i == sel ? Theme.Accent : Theme.CardHi)) g.FillPath(b, p);
            TextRenderer.DrawText(g, Items[i], Theme.Bold, Rectangle.Round(r), i == sel ? Color.White : Theme.Dim,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
        }
    }
}

class Compass : Control
{
    public double? RelAngle; // graus: 0 = em frente, positivo = direita
    public double Dz;
    public string Caption = "";
    public Compass() { DoubleBuffered = true; BackColor = Theme.Card; }
    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        Theme.Smooth(g);
        float s = Math.Min(Width, Height - 22) - 8;
        float cx = Width / 2f, cy = (Height - 22) / 2f + 2;
        using (SolidBrush disc = new SolidBrush(Theme.Bg)) g.FillEllipse(disc, cx - s / 2, cy - s / 2, s, s);
        using (Pen ring = new Pen(Theme.Line, 2)) g.DrawEllipse(ring, cx - s / 2, cy - s / 2, s, s);
        using (Pen tick = new Pen(Theme.Faint, 2))
            for (int i = 0; i < 8; i++)
            {
                double a = i * Math.PI / 4;
                float r1 = s / 2 - 4, r2 = s / 2 - (i % 2 == 0 ? 12 : 8);
                g.DrawLine(tick, cx + (float)(Math.Sin(a) * r1), cy - (float)(Math.Cos(a) * r1), cx + (float)(Math.Sin(a) * r2), cy - (float)(Math.Cos(a) * r2));
            }
        using (SolidBrush fb = new SolidBrush(Theme.Faint)) { SizeF fs = g.MeasureString("FRENTE", Theme.Caps); g.DrawString("FRENTE", Theme.Caps, fb, cx - fs.Width / 2, cy - s / 2 + 14); }
        if (RelAngle.HasValue)
        {
            double a = RelAngle.Value * Math.PI / 180.0;
            float r = s / 2 - 16;
            PointF tip = new PointF(cx + (float)(Math.Sin(a) * r), cy - (float)(Math.Cos(a) * r));
            PointF tail = new PointF(cx - (float)(Math.Sin(a) * r * 0.3), cy + (float)(Math.Cos(a) * r * 0.3));
            using (Pen p = new Pen(Theme.Accent, 7))
            {
                p.StartCap = LineCap.Round;
                p.CustomEndCap = new AdjustableArrowCap(3.2f, 3.2f);
                g.DrawLine(p, tail, tip);
            }
            using (SolidBrush hub = new SolidBrush(Theme.Fg)) g.FillEllipse(hub, cx - 4, cy - 4, 8, 8);
        }
        string vert = !RelAngle.HasValue ? "" : (Dz > 250 ? "▲  suba de andar" : (Dz < -250 ? "▼  desça de andar" : Caption));
        if (vert != "")
            TextRenderer.DrawText(g, vert, Theme.Bold, new Rectangle(0, Height - 22, Width, 20),
                Dz > 250 || Dz < -250 ? Theme.Gold : Theme.Dim, TextFormatFlags.HorizontalCenter | TextFormatFlags.EndEllipsis);
    }
}

// ---------------------------------------------------------------- dados
class Entry
{
    public bool IsGuide, IsArea;
    public string Status = "", Title = "", Where = "", Detail = "", Give = "", Warn = "", ItemId = "", Cat = "";
    public double X, Y, Z, Dist;
    public string Key { get { return Title + "@" + Math.Round(X) + "," + Math.Round(Y) + "," + Math.Round(Z); } }
    public bool OutsideArea { get { return IsArea && (Where == "Fora da mansão" || Where == "Subsolo"); } }
}

class EntryList : ListBox
{
    public Func<Entry, string> Glyph;
    public Func<Entry, Color> Tint;
    public Func<Entry, string> Arrow;
    public EntryList()
    {
        DrawMode = DrawMode.OwnerDrawFixed;
        ItemHeight = 48;
        BorderStyle = BorderStyle.None;
        BackColor = Theme.Card;
        ForeColor = Theme.Fg;
        IntegralHeight = false;
        SetStyle(ControlStyles.OptimizedDoubleBuffer, true);
    }
    protected override void OnHandleCreated(EventArgs e) { base.OnHandleCreated(e); Theme.SetWindowTheme(Handle, "DarkMode_Explorer", null); }
    protected override void OnDrawItem(DrawItemEventArgs e)
    {
        if (e.Index < 0 || e.Index >= Items.Count) return;
        Entry en = (Entry)Items[e.Index];
        Graphics g = e.Graphics;
        Theme.Smooth(g);
        bool sel = (e.State & DrawItemState.Selected) != 0;
        using (SolidBrush bg = new SolidBrush(Theme.Card)) g.FillRectangle(bg, e.Bounds);
        RectangleF row = new RectangleF(e.Bounds.X + 4, e.Bounds.Y + 2, e.Bounds.Width - 8, e.Bounds.Height - 4);
        if (sel)
            using (GraphicsPath p = Theme.Round(row, 8)) using (SolidBrush b = new SolidBrush(Theme.CardHi)) g.FillPath(b, p);
        Color tint = Tint(en);
        if (sel) using (SolidBrush sb = new SolidBrush(Theme.Accent)) g.FillRectangle(sb, row.X, row.Y + 8, 3, row.Height - 16);
        // icone
        RectangleF ic = new RectangleF(row.X + 10, row.Y + (row.Height - 26) / 2, 26, 26);
        using (SolidBrush ib = new SolidBrush(Color.FromArgb(40, tint))) g.FillEllipse(ib, ic);
        TextRenderer.DrawText(g, Glyph(en), Theme.Bold, Rectangle.Round(ic), tint, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
        // distancia + seta
        string dist = (en.Dist / 100.0).ToString("0", CultureInfo.InvariantCulture) + " m";
        string arr = Arrow(en);
        int rightW = 96;
        Rectangle rr = new Rectangle((int)row.Right - rightW - 6, (int)row.Y + 6, rightW, 18);
        TextRenderer.DrawText(g, dist, Theme.Bold, rr, Theme.Fg, TextFormatFlags.Right);
        TextRenderer.DrawText(g, arr, Theme.Small, new Rectangle(rr.X, rr.Y + 19, rightW, 18), arr.StartsWith("▲") || arr.StartsWith("▼") ? Theme.Gold : Theme.Dim, TextFormatFlags.Right);
        // textos
        int tx = (int)ic.Right + 10;
        int tw = (int)row.Right - rightW - 12 - tx;
        Color titleC = en.Status == "feito" ? Theme.Dim : Theme.Fg;
        TextRenderer.DrawText(g, en.Title, Theme.Bold, new Rectangle(tx, (int)row.Y + 5, tw, 20), titleC, TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix);
        string sub = en.Where + (string.IsNullOrEmpty(en.Warn) ? "" : "  ·  🔒 trancado");
        TextRenderer.DrawText(g, sub, Theme.Small, new Rectangle(tx, (int)row.Y + 24, tw, 18), string.IsNullOrEmpty(en.Warn) ? Theme.Dim : Theme.Violet, TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix);
    }
}

// ---------------------------------------------------------------- janela
class MainForm : Form
{
    readonly string cmdPath, statePath;
    readonly Toggle tStamina, tGod, tUnseen, tFreeze, tTraps;
    readonly Slider slSpeed;
    readonly Label lblSpeedVal, lblStatus, lblQuest, lblQuestDesc, lblWhere, lblMsg, lblCount;
    readonly StatBar barHp, barSt;
    readonly Tabs tabs;
    readonly EntryList list;
    readonly Compass compass;
    readonly RichTextBox detail;
    readonly FlatButton btnTp, btnBring, btnGive, btnTop;
    readonly Card cardQuest, cardPlayer, cardList, cardDetail;
    readonly PictureBox logo;
    readonly Timer timer;
    int seqTp = 0, seqBring = 0, seqGive = 0;
    string argTp = "0,0,0", argBring = "0,0,0", argGive = "";
    double yaw, px, py, pz;
    bool hasPos;
    List<Entry> guide = new List<Entry>(), items = new List<Entry>(), areas = new List<Entry>();
    string lastCmd = "", lastDetailKey = "";

    public MainForm()
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        cmdPath = Path.Combine(dir, "cmd.txt");
        statePath = Path.Combine(dir, "state.txt");

        Text = "Spiral Compass";
        try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch (Exception) { }
        ClientSize = new Size(820, 900);
        MinimumSize = new Size(720, 760);
        BackColor = Theme.Bg;
        ForeColor = Theme.Fg;
        Font = Theme.Body;
        StartPosition = FormStartPosition.Manual;
        Location = new Point(30, 30);
        TopMost = true;
        DoubleBuffered = true;

        // Cabecalho
        logo = new PictureBox { SizeMode = PictureBoxSizeMode.Zoom, Size = new Size(38, 38), BackColor = Theme.Bg };
        try { logo.Image = new Icon(Icon, 48, 48).ToBitmap(); } catch (Exception) { }
        Controls.Add(logo);
        Controls.Add(MakeLabel("Spiral Compass", Theme.Title, Theme.Fg, "title"));
        lblStatus = MakeLabel("●  aguardando o jogo", Theme.Small, Theme.Dim, "status");
        Controls.Add(lblStatus);
        btnTop = new FlatButton("📌 Fixado") { Ghost = true, Size = new Size(104, 32), BackColor = Theme.Bg };
        btnTop.Click += delegate { TopMost = !TopMost; btnTop.Text = TopMost ? "📌 Fixado" : "Fixar"; };
        Controls.Add(btnTop);

        // Missao
        cardQuest = new Card { Caption = "Missão atual", Stripe = Theme.Teal };
        lblQuest = MakeLabel("—", Theme.H2, Theme.Teal, null);
        lblQuestDesc = MakeLabel("Abra o mapa do jogo uma vez para o painel ler a missão.", Theme.Body, Theme.Fg, null);
        lblWhere = MakeLabel("", Theme.Small, Theme.Dim, null);
        foreach (Label l in new[] { lblQuest, lblQuestDesc, lblWhere }) { l.BackColor = Theme.Card; cardQuest.Controls.Add(l); }
        Controls.Add(cardQuest);

        // Jogador
        cardPlayer = new Card { Caption = "Jogador" };
        tStamina = new Toggle("Stamina infinita") { Hint = "corre sem cansar" };
        tGod = new Toggle("God mode") { Hint = "vida sempre cheia" };
        tUnseen = new Toggle("Invisível para inimigos") { Hint = "a IA não te enxerga" };
        tFreeze = new Toggle("Congelar inimigos") { Hint = "param no lugar" };
        foreach (Toggle t in new[] { tStamina, tGod, tUnseen, tFreeze }) { t.CheckedChanged += delegate { WriteCmd(); }; cardPlayer.Controls.Add(t); }
        Label lsp = MakeLabel("Velocidade", Theme.Bold, Theme.Fg, "speedlbl"); lsp.BackColor = Theme.Card; cardPlayer.Controls.Add(lsp);
        slSpeed = new Slider();
        slSpeed.ValueChanged += delegate { UpdateSpeedLabel(); WriteCmd(); };
        cardPlayer.Controls.Add(slSpeed);
        lblSpeedVal = MakeLabel("1.0x", Theme.H2, Theme.Fg, "speedval"); lblSpeedVal.BackColor = Theme.Card; lblSpeedVal.TextAlign = ContentAlignment.MiddleRight; lblSpeedVal.AutoSize = false;
        lblSpeedVal.Cursor = Cursors.Hand; lblSpeedVal.Click += delegate { slSpeed.Value = 10; };
        cardPlayer.Controls.Add(lblSpeedVal);
        barHp = new StatBar { Label = "VIDA", Fill = Theme.Accent };
        barSt = new StatBar { Label = "STAMINA", Fill = Theme.Teal };
        cardPlayer.Controls.Add(barHp);
        cardPlayer.Controls.Add(barSt);
        Controls.Add(cardPlayer);

        // Abas
        tabs = new Tabs { Items = new[] { "O que fazer", "Itens no mapa", "Lugares" } };
        tabs.SelectedChanged += delegate { OnTab(); };
        Controls.Add(tabs);

        // Lista
        cardList = new Card { Padding = new Padding(6, 30, 6, 8) };
        lblCount = MakeLabel("", Theme.Small, Theme.Faint, null); lblCount.BackColor = Theme.Card;
        cardList.Controls.Add(lblCount);
        tTraps = new Toggle("armadilhas") { Size = new Size(140, 24), Visible = false };
        tTraps.CheckedChanged += delegate { WriteCmd(); };
        cardList.Controls.Add(tTraps);
        list = new EntryList { Glyph = GlyphOf, Tint = TintOf, Arrow = ArrowOf };
        list.SelectedIndexChanged += delegate { UpdateDetail(true); };
        list.DoubleClick += delegate { Teleport(); };
        cardList.Controls.Add(list);
        Controls.Add(cardList);

        // Detalhe
        cardDetail = new Card { Caption = "Direção" };
        compass = new Compass();
        cardDetail.Controls.Add(compass);
        detail = new RichTextBox { ReadOnly = true, BorderStyle = BorderStyle.None, BackColor = Theme.Card, ForeColor = Theme.Fg, Font = Theme.Body, ScrollBars = RichTextBoxScrollBars.Vertical, DetectUrls = false, TabStop = false };
        detail.HandleCreated += delegate { Theme.SetWindowTheme(detail.Handle, "DarkMode_Explorer", null); };
        cardDetail.Controls.Add(detail);
        btnTp = new FlatButton("Ir até lá") { Fill = Theme.Accent };
        btnBring = new FlatButton("Trazer item até mim") { Fill = Color.FromArgb(52, 98, 150) };
        btnGive = new FlatButton("Receber itens (pular)") { Fill = Color.FromArgb(104, 72, 148) };
        btnTp.Click += delegate { Teleport(); };
        btnBring.Click += delegate { Bring(); };
        btnGive.Click += delegate { Give(); };
        foreach (FlatButton b in new[] { btnTp, btnBring, btnGive }) { b.Enabled = false; cardDetail.Controls.Add(b); }
        Controls.Add(cardDetail);

        lblMsg = MakeLabel("", Theme.Small, Theme.Gold, null);
        Controls.Add(lblMsg);

        Resize += delegate { DoLayout(); };
        DoLayout();
        OnTab();
        UpdateSpeedLabel();
        ShowPlaceholder();

        WriteCmd();
        timer = new Timer { Interval = 300 };
        timer.Tick += delegate { ReadState(); };
        timer.Start();
    }

    protected override void OnHandleCreated(EventArgs e) { base.OnHandleCreated(e); Theme.DarkTitle(this); }

    Label MakeLabel(string text, Font f, Color c, string name)
    {
        Label l = new Label { Text = text, Font = f, ForeColor = c, BackColor = Theme.Bg, AutoSize = true, UseMnemonic = false };
        if (name != null) l.Name = name;
        return l;
    }

    // ------------------------------------------------------------ layout responsivo
    void DoLayout()
    {
        int W = ClientSize.Width, H = ClientSize.Height, m = 16, gap = 12;
        int iw = W - 2 * m;
        logo.Location = new Point(m, 14);
        Control title = Controls["title"];
        title.Location = new Point(m + 46, 12);
        lblStatus.Location = new Point(m + 48, 40);
        btnTop.Location = new Point(W - m - btnTop.Width, 18);
        int y = 64;

        // Missao (altura conforme o texto)
        cardQuest.SetBounds(m, y, iw, 10);
        lblQuest.Location = new Point(18, 28);
        lblQuestDesc.MaximumSize = new Size(iw - 36, 0);
        lblQuestDesc.Location = new Point(18, 54);
        lblWhere.Location = new Point(18, lblQuestDesc.Bottom + 6);
        cardQuest.Height = lblWhere.Bottom + 12;
        y = cardQuest.Bottom + gap;

        // Jogador: 4 interruptores em grade 2x2 + velocidade + barras
        int pw = iw;
        cardPlayer.SetBounds(m, y, pw, 196);
        int colW = (pw - 28) / 2;
        tStamina.SetBounds(14, 30, colW, 44); tGod.SetBounds(14 + colW, 30, colW, 44);
        tUnseen.SetBounds(14, 76, colW, 44); tFreeze.SetBounds(14 + colW, 76, colW, 44);
        Control lsp = cardPlayer.Controls["speedlbl"];
        lsp.Location = new Point(16, 132);
        slSpeed.SetBounds(100, 128, pw - 100 - 90, 28);
        lblSpeedVal.SetBounds(pw - 86, 126, 70, 30);
        barHp.SetBounds(16, 160, colW - 20, 34);
        barSt.SetBounds(14 + colW + 2, 160, colW - 16, 34);
        cardPlayer.Height = 204;
        y = cardPlayer.Bottom + gap;

        tabs.SetBounds(m, y, iw, 38);
        y = tabs.Bottom + gap;

        int bottom = H - 34;
        int detailW = Math.Max(260, (int)(iw * 0.40));
        int listW = iw - detailW - gap;
        cardList.SetBounds(m, y, listW, bottom - y);
        lblCount.Location = new Point(14, 9);
        tTraps.Location = new Point(listW - tTraps.Width - 8, 4);
        list.SetBounds(6, 30, listW - 12, cardList.Height - 38);

        cardDetail.SetBounds(m + listW + gap, y, detailW, bottom - y);
        int cw = detailW - 28;
        int compassH = Math.Min(180, Math.Max(140, (cardDetail.Height - 220) / 2));
        compass.SetBounds(14, 28, cw, compassH);
        int nBtn = tabs.Selected == 2 ? 1 : 2;
        int btnArea = nBtn * 42;
        detail.SetBounds(16, compass.Bottom + 10, cw - 2, cardDetail.Height - compass.Bottom - 10 - btnArea - 14);
        int by = cardDetail.Height - btnArea - 8;
        btnTp.SetBounds(14, by, cw, 36);
        btnBring.SetBounds(14, by + 42, cw, 36);
        btnGive.SetBounds(14, by + 42, cw, 36);

        lblMsg.Location = new Point(m, H - 26);
        lblMsg.MaximumSize = new Size(iw, 20);
        Invalidate(true);
    }

    // ------------------------------------------------------------ abas e lista
    void OnTab()
    {
        int t = tabs.Selected;
        tTraps.Visible = t == 1;
        btnBring.Visible = t == 1;
        btnGive.Visible = t == 0;
        list.Items.Clear();
        lastDetailKey = "";
        DoLayout();
        RefreshList();
        ShowPlaceholder();
    }

    List<Entry> Current { get { return tabs.Selected == 0 ? guide : (tabs.Selected == 1 ? items : areas); } }

    void RefreshList()
    {
        List<Entry> shown = Current;
        bool same = shown.Count == list.Items.Count;
        if (same)
            for (int i = 0; i < shown.Count; i++)
            {
                Entry old = (Entry)list.Items[i];
                if (old.Key != shown[i].Key || old.Status != shown[i].Status || old.Warn != shown[i].Warn) { same = false; break; }
            }
        if (same)
        {
            for (int i = 0; i < shown.Count; i++) list.Items[i] = shown[i];
        }
        else
        {
            string selKey = Selected != null ? Selected.Key : null;
            int top = list.TopIndex;
            list.BeginUpdate();
            list.Items.Clear();
            foreach (Entry e in shown) list.Items.Add(e);
            for (int i = 0; i < shown.Count; i++) if (shown[i].Key == selKey) { list.SelectedIndex = i; break; }
            if (top < list.Items.Count) list.TopIndex = top;
            list.EndUpdate();
        }
        string[] what = { "passos", "itens", "lugares" };
        int done = 0;
        if (tabs.Selected == 0) foreach (Entry e in guide) if (e.Status == "feito") done++;
        lblCount.Text = shown.Count + " " + what[tabs.Selected] + (tabs.Selected == 0 && shown.Count > 0 ? "  ·  " + done + " resolvidos" : "");
        UpdateDetail(false);
    }

    Entry Selected { get { return list.SelectedIndex >= 0 && list.SelectedIndex < list.Items.Count ? (Entry)list.Items[list.SelectedIndex] : null; } }

    string GlyphOf(Entry e)
    {
        if (e.IsArea) return "⌂";
        if (!e.IsGuide) return string.IsNullOrEmpty(e.Warn) ? "◆" : "🔒";
        switch (e.Status) { case "agora": return "▶"; case "pronto": return "★"; case "falta": return "…"; default: return "✓"; }
    }

    Color TintOf(Entry e)
    {
        if (e.IsArea) return e.OutsideArea ? Theme.Violet : Theme.Teal;
        if (!e.IsGuide) return e.Cat == "Armadilha" ? Theme.Dim : (string.IsNullOrEmpty(e.Warn) ? Theme.Gold : Theme.Violet);
        switch (e.Status) { case "agora": return Theme.Teal; case "pronto": return Theme.Gold; case "falta": return Theme.Blue; default: return Theme.Green; }
    }

    string ArrowOf(Entry e)
    {
        if (!hasPos) return "";
        double dz = e.Z - pz;
        if (dz > 250) return "▲ subir";
        if (dz < -250) return "▼ descer";
        string[] a = { "↑ frente", "↗ frente-dir.", "→ direita", "↘ trás-dir.", "↓ atrás", "↙ trás-esq.", "← esquerda", "↖ frente-esq." };
        return a[(int)Math.Round(((RelAngle(e) + 360) % 360) / 45.0) % 8];
    }

    // ------------------------------------------------------------ detalhe
    void ShowPlaceholder()
    {
        string[] tips = {
            "Escolha um passo na lista.\n\n▶ uma companheira te espera\n★ você já tem tudo para resolver\n… falta algum item\n✓ já resolvido",
            "Escolha um item na lista.\n\n\"Trazer item até mim\" é o jeito mais seguro: o item vem até você e você pega normalmente.",
            "Escolha um lugar e clique em \"Ir até lá\".\n\nLugares em roxo pertencem a outros capítulos."
        };
        SetRich(new[] { tips[tabs.Selected] }, null);
        compass.RelAngle = null;
        compass.Invalidate();
    }

    void SetRich(string[] paragraphs, string title)
    {
        detail.SuspendLayout();
        detail.Clear();
        if (title != null) Append(title + "\n", Theme.H2, Theme.Fg);
        foreach (string para in paragraphs)
        {
            foreach (string raw in para.Replace("\r", "").Split('\n'))
            {
                string line = raw;
                if (line.EndsWith(":") && line.Length < 40) Append(line.ToUpperInvariant() + "\n", Theme.Caps, Theme.Accent);
                else if (line.StartsWith("✔")) Append(line + "\n", Theme.Bold, Theme.Green);
                else if (line.StartsWith("⚠")) Append(line + "\n", Theme.Bold, Theme.Gold);
                else if (line.StartsWith("• "))
                {
                    int dash = line.IndexOf(" — ");
                    if (dash > 0)
                    {
                        Append("• " + line.Substring(2, dash - 2), Theme.Bold, Theme.Fg);
                        string st = line.Substring(dash + 3);
                        Append("\n   " + st + "\n", Theme.Small, st.StartsWith("✔") ? Theme.Green : (st.StartsWith("no mapa") ? Theme.Gold : Theme.Dim));
                    }
                    else Append(line + "\n", Theme.Body, Theme.Fg);
                }
                else Append(line + "\n", Theme.Body, line.StartsWith("Local:") ? Theme.Dim : Theme.Fg);
            }
        }
        detail.SelectionStart = 0;
        detail.ScrollToCaret();
        detail.ResumeLayout();
    }

    void Append(string s, Font f, Color c)
    {
        detail.SelectionStart = detail.TextLength;
        detail.SelectionLength = 0;
        detail.SelectionFont = f;
        detail.SelectionColor = c;
        detail.AppendText(s);
    }

    void UpdateDetail(bool force)
    {
        Entry e = Selected;
        btnTp.Enabled = e != null;
        btnBring.Enabled = e != null && !e.IsGuide && !e.IsArea;
        btnGive.Enabled = e != null && !string.IsNullOrEmpty(e.Give);
        if (e == null) { if (force) ShowPlaceholder(); return; }
        if (hasPos)
        {
            compass.RelAngle = RelAngle(e);
            compass.Dz = e.Z - pz;
            compass.Caption = (e.Dist / 100.0).ToString("0", CultureInfo.InvariantCulture) + " m daqui";
            compass.Invalidate();
        }
        string key = e.Key + "|" + e.Status + "|" + e.Detail + "|" + e.Warn;
        if (!force && key == lastDetailKey) return;
        lastDetailKey = key;
        if (e.IsArea)
            SetRich(new[] { e.Where, e.OutsideArea ? "⚠ Área de outros capítulos: ir antes da hora pode travar a história." : "Duplo clique na lista também teleporta." }, e.Title);
        else if (e.IsGuide)
            SetRich(new[] { e.Detail }, e.Title);
        else
            SetRich(new[] { e.Where, string.IsNullOrEmpty(e.Warn) ? "" : "⚠ " + e.Warn, "", "\"Trazer item até mim\" é mais seguro que o teleporte: o item vem até você e você pega normalmente." }, e.Title);
    }

    // ------------------------------------------------------------ comandos
    double SpeedMult { get { return slSpeed.Value / 10.0; } }
    void UpdateSpeedLabel() { lblSpeedVal.Text = SpeedMult.ToString("0.0", CultureInfo.InvariantCulture) + "x"; lblSpeedVal.ForeColor = slSpeed.Value == 10 ? Theme.Fg : Theme.AccentHi; }

    void WriteCmd()
    {
        if (slSpeed == null || tFreeze == null || tTraps == null) return;
        string s = "stamina=" + (tStamina.Checked ? 1 : 0) + "\n"
            + "god=" + (tGod.Checked ? 1 : 0) + "\n"
            + "unseen=" + (tUnseen.Checked ? 1 : 0) + "\n"
            + "freeze=" + (tFreeze.Checked ? 1 : 0) + "\n"
            + "traps=" + (tTraps.Checked ? 1 : 0) + "\n"
            + "speed=" + SpeedMult.ToString("0.0", CultureInfo.InvariantCulture) + "\n"
            + "tp=" + seqTp + ":" + argTp + "\n"
            + "bring=" + seqBring + ":" + argBring + "\n"
            + "give=" + seqGive + ":" + argGive + "\n";
        if (s == lastCmd) return;
        try
        {
            string tmp = cmdPath + ".tmp";
            File.WriteAllText(tmp, s);
            if (File.Exists(cmdPath)) File.Delete(cmdPath);
            File.Move(tmp, cmdPath);
            lastCmd = s;
        }
        catch (IOException) { lastCmd = ""; }
    }

    static string Coord(Entry e) { return string.Format(CultureInfo.InvariantCulture, "{0:0},{1:0},{2:0}", e.X, e.Y, e.Z); }

    bool Confirm(string text, string caption)
    {
        return MessageBox.Show(this, text, caption, MessageBoxButtons.YesNo, MessageBoxIcon.Warning) == DialogResult.Yes;
    }

    void Teleport()
    {
        Entry e = Selected;
        if (e == null) return;
        if (!string.IsNullOrEmpty(e.Warn) && !Confirm(e.Warn + ".\n\nTeleportar para dentro de uma área trancada pode quebrar a ordem da história.\nPrefira \"Trazer item até mim\".\n\nTeleportar mesmo assim?", "Área trancada")) return;
        if (e.OutsideArea && !Confirm("\"" + e.Title + "\" é usado em outros capítulos da história.\nIr até lá antes da hora pode mostrar áreas fechadas ou travar eventos.\n\nTeleportar mesmo assim?", "Área de outro capítulo")) return;
        argTp = Coord(e) + (e.IsArea ? ",e" : "");
        seqTp++;
        WriteCmd();
    }

    void Bring()
    {
        Entry e = Selected;
        if (e == null || e.IsGuide || e.IsArea) return;
        argBring = Coord(e);
        seqBring++;
        WriteCmd();
    }

    void Give()
    {
        Entry e = Selected;
        if (e == null || string.IsNullOrEmpty(e.Give)) return;
        if (!Confirm("Isto coloca os itens direto no seu inventário (modo debug dos desenvolvedores).\nUse só se estiver travado: pode pular cenas ou eventos da história.\n\nContinuar?", "Receber itens")) return;
        argGive = e.Give;
        seqGive++;
        WriteCmd();
    }

    // ------------------------------------------------------------ estado vindo do jogo
    void SetStatus(string s, Color c) { string t = "●  " + s; if (lblStatus.Text != t) lblStatus.Text = t; lblStatus.ForeColor = c; }

    void ReadState()
    {
        WriteCmd(); // re-tenta se a escrita anterior falhou
        string[] lines;
        try
        {
            if (!File.Exists(statePath)) { SetStatus("aguardando o jogo", Theme.Dim); return; }
            if ((DateTime.Now - File.GetLastWriteTime(statePath)).TotalSeconds > 5) { SetStatus("jogo fechado ou pausado", Theme.Dim); return; }
            lines = File.ReadAllLines(statePath);
        }
        catch (IOException) { return; }

        Dictionary<string, string> kv = new Dictionary<string, string>();
        List<Entry> gs = new List<Entry>(), ts = new List<Entry>(), ars = new List<Entry>();
        foreach (string line in lines)
        {
            int eq = line.IndexOf('=');
            if (eq < 0) continue;
            string k = line.Substring(0, eq), v = line.Substring(eq + 1);
            string[] p = v.Split('|');
            if (k == "t" && p.Length >= 9)
                ts.Add(new Entry { Cat = p[0], Title = p[1], X = D(p[2]), Y = D(p[3]), Z = D(p[4]), Dist = D(p[5]), Where = p[6], Warn = p[7], ItemId = p[8] });
            else if (k == "g" && p.Length >= 9)
                gs.Add(new Entry { IsGuide = true, Status = p[0], Title = p[1], X = D(p[2]), Y = D(p[3]), Z = D(p[4]), Dist = D(p[5]), Where = p[6], Detail = p[7].Replace("\\n", "\n"), Give = p[8] });
            else if (k == "a" && p.Length >= 6)
                ars.Add(new Entry { IsArea = true, Where = p[0], Title = p[1], X = D(p[2]), Y = D(p[3]), Z = D(p[4]), Dist = D(p[5]) });
            else kv[k] = v;
        }

        if (Get(kv, "ingame") != "1") { SetStatus("no menu / carregando", Theme.Dim); return; }
        SetStatus("conectado ao jogo", Theme.Green);

        barHp.Set(D(Get(kv, "hp")), D(Get(kv, "maxhp")));
        barSt.Set(D(Get(kv, "stamina")), D(Get(kv, "maxstamina")));
        string wh = "📍 Você está em: " + Get(kv, "where");
        if (lblWhere.Text != wh) lblWhere.Text = wh;
        if (kv.ContainsKey("quest") && lblQuest.Text != kv["quest"])
        {
            lblQuest.Text = kv["quest"];
            lblQuestDesc.Text = Get(kv, "questdesc");
            DoLayout();
        }
        string msg = Get(kv, "msg");
        if (msg != "?" && lblMsg.Text != msg) lblMsg.Text = msg;

        yaw = D(Get(kv, "yaw"));
        string[] pos = Get(kv, "pos").Split(',');
        hasPos = pos.Length == 3;
        if (hasPos) { px = D(pos[0]); py = D(pos[1]); pz = D(pos[2]); }

        guide = gs; items = ts; areas = ars;
        RefreshList();
        list.Invalidate();
    }

    static string Get(Dictionary<string, string> kv, string k) { string v; return kv.TryGetValue(k, out v) ? v : "?"; }
    static double D(string s) { double d; double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out d); return d; }

    double RelAngle(Entry t)
    {
        double rel = Math.Atan2(t.Y - py, t.X - px) * 180.0 / Math.PI - yaw;
        while (rel > 180) rel -= 360;
        while (rel < -180) rel += 360;
        return rel;
    }

    [STAThread]
    static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new MainForm());
    }
}
