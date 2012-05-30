# Why not use Graphite and Etsy's Statsd implementation?

Graphite and etsy's version of statsd are both excellent pieces of software, 
with active and vibrant communities. They're well maintained, well architected, 
and widely used.

So why did we make batsd (and the three distinct predecessor versions)? 
There are a few reasons:

1) **Lingua Franca**. 37signals (not surprisingly) primarily uses Ruby. 
Our apps are written in Ruby, the configuration management system we use 
has a Ruby DSL, and we collectively have over a hundred years worth of 
experience in Ruby. We've done a small amount with Node.js as an 
organization (which Etsy's version of statsd is written in), but 
nothing really with Python or Django (which graphite is written in).  
Both are great languages, but we're comparative novices in those 
languages.  We used etsy's statsd and graphite briefly, and found 
ourselves in a whole world of new dependencies, Chef cookbooks, 
and ways of running apps.

We want to be comfortable with our tools and be able to read, understand, 
and modify the source of those tools so that they aren't black box 
dependencies. We could learn, but it's not what we know. 

2) **We weren't going to use graphite's UI much**. One of the great things 
about Graphite is it's interface, but we knew from the start we weren't 
going to end up using it much. We have upwards of a dozen distinct data 
repositories (statsd, MySQL, third party APIs, etc. ), and we knew we 
wanted to be able to compare and analyze them in a common UI anyway. 

We developed our own tool called "Flyash" (a play on "Graphite") to 
accomplish this that's similar in many ways to Graphite (we'll release this 
eventually),  so we weren't going to benefit from one of the best parts 
of Graphite anyway.

3) **It looked like it would be easy**. Looks can be deceiving. In all 
seriousness, it's been a great learning experience and a lot of fun building it.
