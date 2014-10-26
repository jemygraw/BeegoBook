在上面的两篇文章中，我们介绍了beego的logs模块的基本信息和结构，现在我们将开始重点介绍每种日志输出方式。

终端输出日志方式是我们开发程序时最常用的日志输出方式，beego的日志终端输出实现很简单。我们主要看一下它所实现的接口方法。

**Init**

```go
func (c *ConsoleWriter) Init(jsonconfig string) error {
	if len(jsonconfig) == 0 {
		return nil
	}
	err := json.Unmarshal([]byte(jsonconfig), c)
	if err != nil {
		fmt.Println(err)
		return err
	}
	return nil
}
```
从上面的代码我们可以看出来，初始化方法主要是根据它的调用者`SetLogger`方法提供的json格式的字符串来进行一些配置。这里需要注意的是`ConsoleWriter`这个结构体，它实现了`LoggerInterface`的方法，成为了一种日志记录方式。

```go
type ConsoleWriter struct {
	lg    *log.Logger
	Level int `json:"level"`
}
```
从这个结构体，我们可以看出`ConsoleWriter`的配置参数只有`level`一个，即设置日志的输出到终端的等级。

**WriteMsg**

```go
func (c *ConsoleWriter) WriteMsg(msg string, level int) error {
	if level > c.Level {
		return nil
	}
	if goos := runtime.GOOS; goos == "windows" {
		c.lg.Println(msg)
	} else {
		c.lg.Println(colors[level](msg))
	}
	return nil
}
```
这个方法是将日志从缓冲区写出去到终端，它首先判断缓冲区里面的日志的等级，如果里面的日志等级低于日志的输出等级（日志等级越低值越大），那么不输出；否则的话判断一下操作系统，如果是windows系统，直接输出到终端，否则以带颜色的方式输出到终端（*nix系统支持终端颜色）。

最后我们看一个例子：

```go
package main

import (
	"fmt"
	"github.com/astaxie/beego/logs"
)

func main() {
	//创建一个BeeLogger
	log := logs.NewLogger(1000)
	//设置BeeLogger日志等级
	log.SetLevel(logs.LevelDebug)
	//console方式的日志记录方式只有一个配置参数level，
	//这里的日志级别是日志的输出等级，而上面的SetLevel设置的等级是日志写入缓冲区的等级
	//也就是说如果SetLevel设置的等级高于以参数方式提供的等级，则将以SetLevel的等级为准
	//否则的话，则最终输出的日志以参数方式提供的等级为准。
	log.SetLogger("console", fmt.Sprintf("{\"level\":%d}", logs.LevelNotice))
	log.Debug("%s", "this is a debug message")
	log.Informational("%s", "this is an informational message")
	log.Notice("%s", "this is a notice message")
	log.Flush()
	//由于beego的日志是由单独的协程输出的，这里阻塞一下程序让协程有机会执行
	fmt.Scanln()
	//关闭日志
	log.Close()
}
```
上面的例子中，我们设置日志写入缓冲区的等级为LevelDebug，而日志输出到终端的等级为LevelNotice，所以根据预期，只有最后一个Notice级别的日志才会被输出，但是这三条信息都会被写入日志缓冲区。

另外由于beego的日志是由单独的协程来写出到终端等设备的，所以我们用`fmt.Scanln()`来阻塞main函数的执行，让协程得以调度执行，最后我们关闭这个日志记录器。

上面例子的输出为：

>2014/08/22 21:37:25 [W] this is a notice message

上面讲解了beego的logs模块的终端输出的方式，接下来我们再看看其余的几种方式。

未完待续。。。
