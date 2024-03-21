trait ArrayTraitExt<T> {
    fn contains<+PartialEq<T>>(self: @Array<T>, item: T) -> bool;
}

trait SpanTraitExt<T> {
    fn contains<+PartialEq<T>>(self: Span<T>, item: T) -> bool;
}

impl ArrayImpl<T, +Copy<T>, +Drop<T>> of ArrayTraitExt<T> {
    fn contains<+PartialEq<T>>(self: @Array<T>, item: T) -> bool {
        self.span().contains(item)
    }
}

impl SpanImpl<T, +Copy<T>, +Drop<T>> of SpanTraitExt<T> {
    fn contains<+PartialEq<T>>(mut self: Span<T>, item: T) -> bool {
        loop {
            match self.pop_front() {
                Option::Some(v) => { if *v == item {
                    break true;
                } },
                Option::None => { break false; },
            };
        }
    }
}
