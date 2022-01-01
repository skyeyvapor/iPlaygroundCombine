/*:
 # Combine DIY
 ## Preparation
 */

import PlaygroundSupport
import Foundation

PlaygroundPage.current.needsIndefiniteExecution = true

let url = URL(string: "https://www.example.com")!

func handleData(_ data: Data) {
    print(data)
}

/*:
 ## URLSession.dataTask(with:completionHandler:)
 */
let task = URLSession.shared.dataTask(with: url) { data, response, error in
    if let data = data {
        handleData(data)
    }
}
task.resume()

/*:
 ## Abstraction with Closure
 */
let subscribe = {
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let data = data {
            handleData(data)
        }
    }
    task.resume()
}
subscribe()
/*:
 ## Abstraction with Structure
 */
/* 1.
struct Publisher {
    let subscribe = { (valueHandler: @escaping (Data) -> Void) in  // 變成subscribe是一個closure，takes一個closure input
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                valueHandler(data)
            }
        }
        task.resume()
    }
}
Publisher().subscribe { data in
    handleData(data)
}  // 最後一個parameter是block可省略()，並trailing
*/
// >>>>>>>>>>

/* 2.
struct Publisher<Value> {  // 把原先是Data的部分變成generic
    let subscribe: (@escaping (Value) -> Void) -> Void  // 定義subscribe是一個closure，takes一個closure input
}
// Publisher<Any>  Expected member name or constructor call after type name
// Publisher<Any>()  Missing argument for parameter 'subscribe' in call
// Publisher {}  Generic parameter 'Value' could not be inferred
// Publisher<Any>(subscribe: <#(@escaping (Any) -> Void) -> Void#>)

Publisher { valueHandler in  // <type>從valueHandler的data infer 出來了  // 原先是一個constructor with subscribe，剛好是最後個parameter所以也去掉了()
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let data = data {
            valueHandler(data)
        }
    }
    task.resume()
}
.subscribe { data in
    handleData(data)
}
*/

// 如今我們成功建立訂閱關係，但無法管理訂閱關係，也就是無法取消
// 所以我們要抽象化subscription
// 採用reference type是因為能deinit
class Subscription {
    let cancel: () -> Void
    init(cancel: @escaping () -> Void) {
        self.cancel = cancel
    }
    deinit {
        cancel()
    }
}

struct Publisher<Value> {
    let subscribe: (@escaping (Value) -> Void) -> Subscription
}

let subscription = Publisher { valueHandler in  // 把整段可執行並執行的東西assign給一個變數subscription，像task.resume()也可以assign給一個變數，可看成整個execution被assign了，也可看成執行完後的return的東西被assign
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let data = data {
            valueHandler(data)
        }
    }
    task.resume()
    return Subscription { task.cancel() }  // 並且return一個新init的Subscription object，裡面的cancel功能是task.cancel
}
.subscribe { data in handleData(data) }

subscription.cancel()  // 執行完後馬上cancel
/*:
 ## Subscription
 */



/*:
 ## NotificationCenter
 */



/*:
 ## Extension
 */
extension URLSession {
    func dataPublisher(for url: URL) -> Publisher<Data> {
        return Publisher { valueHandler in
            let task = self.dataTask(with: url) { data, response, error in
                if let data = data {
                    valueHandler(data)
                }
            }
            task.resume()
            return Subscription { task.cancel() }
        }
    }
}
URLSession.shared.dataPublisher(for: url)  // 需要個變數hold住，不然會被釋放掉，加上因為我們寫了deinit的時候會自動呼叫cancel
    .subscribe { data in
        handleData(data)
    }
/*:
 ## map(_:)
 */
// 因為放進這些操作時，這些值可能都還沒存在，所以無法用if let解開，只能用map丟進去
extension Publisher {
    func map<NewValue>(_ transform: @escaping (Value) -> NewValue) -> Publisher<NewValue> {
        return Publisher<NewValue> { newValueHandler in
            self.subscribe { value in  // 這邊是return Swift 5.1開始只有一行不用寫return
                let newValue = transform(value)
                newValueHandler(newValue)
            }
        }
    }
}

func handleCount(_ count: Int) { print(count) }
let sub = URLSession.shared.dataPublisher(for: url)
    .map { $0.count }
    .subscribe { handleCount($0) }
