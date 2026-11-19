import Foundation
let u = URL(fileURLWithPath: CommandLine.arguments[1])
let d = try! u.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
try! d.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("bookmark bytes:", d.count)
