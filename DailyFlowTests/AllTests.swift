import Testing

/// Корневой суит с .serialized — все вложенные тесты выполняются последовательно,
/// предотвращая конкурентную инициализацию ModelContainer в SwiftData.
@Suite("DailyFlow Tests", .serialized)
struct DailyFlowTests {}
