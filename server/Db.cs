using System.Data;
using System.Data.OleDb;
using System.Text.RegularExpressions;

// MDB 접근 계층. 서버 프로그램만 MDB를 직접 열고, 다른 PC/모바일은 API로만 접근한다.
public static class Db
{
    static readonly object Gate = new();
    public static string Path = "";
    public static string Provider = "Microsoft.Jet.OLEDB.4.0"; // 32비트 프로세스에서는 Windows 기본 내장
    public static string ConnStr => $"Provider={Provider};Data Source={Path};";

    public static void Init(string path, string provider)
    {
        Path = path;
        if (!string.IsNullOrWhiteSpace(provider)) Provider = provider;
        if (!File.Exists(Path))
        {
            Directory.CreateDirectory(System.IO.Path.GetDirectoryName(System.IO.Path.GetFullPath(Path))!);
            var t = Type.GetTypeFromProgID("ADOX.Catalog") ?? throw new Exception("ADOX를 찾을 수 없습니다 (Windows 필요)");
            dynamic cat = Activator.CreateInstance(t)!;
            cat.Create($"Provider={Provider};Data Source={Path};Jet OLEDB:Engine Type=5");
            System.Runtime.InteropServices.Marshal.ReleaseComObject(cat);
        }
        Schema();
    }

    static void Schema()
    {
        string[] ddl = {
          "CREATE TABLE Users (Id COUNTER PRIMARY KEY, LoginName TEXT(40), Pin TEXT(64), DisplayName TEXT(40), Role TEXT(10), Active YESNO)",
          "CREATE TABLE Products (Id COUNTER PRIMARY KEY, Barcode TEXT(40), Name TEXT(100), Category TEXT(40), Price LONG, Cost LONG, Stock LONG, MinStock LONG, VendorId LONG, Active YESNO, Memo TEXT(200))",
          "CREATE TABLE Customers (Id COUNTER PRIMARY KEY, Name TEXT(60), Phone TEXT(30), Address TEXT(120), Balance LONG, Memo TEXT(200), Active YESNO)",
          "CREATE TABLE Vendors (Id COUNTER PRIMARY KEY, Name TEXT(60), Phone TEXT(30), BizNo TEXT(20), Address TEXT(120), Memo TEXT(200), Active YESNO)",
          "CREATE TABLE Sales (Id COUNTER PRIMARY KEY, SaleNo TEXT(20), SaleDate DATETIME, CustomerId LONG, UserName TEXT(40), Total LONG, Discount LONG, Paid LONG, PayMethod TEXT(10), Cancelled YESNO, Memo TEXT(200))",
          "CREATE TABLE SaleItems (Id COUNTER PRIMARY KEY, SaleId LONG, ProductId LONG, Name TEXT(100), Qty LONG, Price LONG, Amount LONG)",
          "CREATE TABLE StockMoves (Id COUNTER PRIMARY KEY, MoveDate DATETIME, ProductId LONG, Delta LONG, Reason TEXT(20), RefId LONG, UserName TEXT(40), Memo TEXT(200))",
          "CREATE TABLE Settings (K TEXT(40) PRIMARY KEY, V TEXT(255))",
        };
        foreach (var s in ddl) { try { Exec(s); } catch (OleDbException) { /* 이미 존재 */ } }
        if (Scalar("SELECT COUNT(*) FROM Users") is int n && n == 0)
            Exec("INSERT INTO Users (LoginName,Pin,DisplayName,Role,Active) VALUES (?,?,?,?,?)", "admin", Auth.Hash("1234"), "관리자", "admin", true);
    }

    // Jet 예약어(Name, Memo, Role)가 열 이름일 때 대괄호로 감싼다
    public static string Fix(string sql) => Regex.Replace(sql, @"(?<![\[\w])(Name|Memo|Role)(?![\w\]])", "[$1]");

    static OleDbCommand Cmd(OleDbConnection c, string sql, object[] p)
    {
        var cmd = new OleDbCommand(Fix(sql), c);
        foreach (var v in p)
        {
            var prm = new OleDbParameter { Value = v ?? DBNull.Value };
            if (v is DateTime) prm.OleDbType = OleDbType.Date;
            cmd.Parameters.Add(prm);
        }
        return cmd;
    }

    public static List<Dictionary<string, object>> Query(string sql, params object[] p)
    {
        lock (Gate)
        {
            using var c = new OleDbConnection(ConnStr); c.Open();
            using var r = Cmd(c, sql, p).ExecuteReader();
            return Read(r);
        }
    }

    static List<Dictionary<string, object>> Read(OleDbDataReader r)
    {
        var list = new List<Dictionary<string, object>>();
        while (r.Read())
        {
            var d = new Dictionary<string, object>();
            for (int i = 0; i < r.FieldCount; i++)
            {
                var v = r.GetValue(i);
                if (v is DBNull) v = null;
                else if (v is DateTime dt) v = dt.ToString("yyyy-MM-dd HH:mm:ss");
                d[r.GetName(i)] = v;
            }
            list.Add(d);
        }
        return list;
    }

    public static int Exec(string sql, params object[] p)
    {
        lock (Gate)
        {
            using var c = new OleDbConnection(ConnStr); c.Open();
            return Cmd(c, sql, p).ExecuteNonQuery();
        }
    }

    public static object Scalar(string sql, params object[] p)
    {
        lock (Gate)
        {
            using var c = new OleDbConnection(ConnStr); c.Open();
            var v = Cmd(c, sql, p).ExecuteScalar();
            return v is DBNull ? null : v;
        }
    }

    // 여러 문장을 하나의 트랜잭션으로 실행 (판매 처리 등)
    public static T Tx<T>(Func<Tx, T> work)
    {
        lock (Gate)
        {
            using var c = new OleDbConnection(ConnStr); c.Open();
            using var t = c.BeginTransaction();
            try { var res = work(new Tx(c, t)); t.Commit(); return res; }
            catch { t.Rollback(); throw; }
        }
    }
}

public class Tx
{
    readonly OleDbConnection c; readonly OleDbTransaction t;
    public Tx(OleDbConnection c, OleDbTransaction t) { this.c = c; this.t = t; }
    public int Exec(string sql, params object[] p)
    {
        using var cmd = new OleDbCommand(Db.Fix(sql), c, t);
        foreach (var v in p) { var prm = new OleDbParameter { Value = v ?? DBNull.Value }; if (v is DateTime) prm.OleDbType = OleDbType.Date; cmd.Parameters.Add(prm); }
        return cmd.ExecuteNonQuery();
    }
    public int Insert(string sql, params object[] p)
    {
        Exec(sql, p);
        using var cmd = new OleDbCommand("SELECT @@IDENTITY", c, t);
        return Convert.ToInt32(cmd.ExecuteScalar());
    }
    public List<Dictionary<string, object>> Query(string sql, params object[] p)
    {
        using var cmd = new OleDbCommand(Db.Fix(sql), c, t);
        foreach (var v in p) cmd.Parameters.Add(new OleDbParameter { Value = v ?? DBNull.Value });
        using var r = cmd.ExecuteReader();
        var list = new List<Dictionary<string, object>>();
        while (r.Read()) { var d = new Dictionary<string, object>(); for (int i = 0; i < r.FieldCount; i++) { var v = r.GetValue(i); d[r.GetName(i)] = v is DBNull ? null : v; } list.Add(d); }
        return list;
    }
    public object Scalar(string sql, params object[] p)
    {
        using var cmd = new OleDbCommand(Db.Fix(sql), c, t);
        foreach (var v in p) cmd.Parameters.Add(new OleDbParameter { Value = v ?? DBNull.Value });
        var r = cmd.ExecuteScalar(); return r is DBNull ? null : r;
    }
}
