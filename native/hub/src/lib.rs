mod catalog;
mod engine;
mod lexicon;
mod math;
mod profile;
mod rng;
mod signals;
mod vault;

use engine::Command;
use rinf::{DartSignal, dart_shutdown, write_interface};
use signals::{
    BootRequest, ChangeBet, EnterRoom, NotificationsAnswered, RefillRequest, SpinRequest,
    WheelSpinRequest,
};
use tokio::sync::mpsc::{UnboundedSender, unbounded_channel};

write_interface!();

fn forward<T>(outbox: &UnboundedSender<Command>, wrap: fn(T) -> Command)
where
    T: DartSignal + Send + 'static,
{
    let outbox = outbox.clone();
    tokio::spawn(async move {
        let receiver = T::get_dart_signal_receiver();
        while let Some(pack) = receiver.recv().await {
            if outbox.send(wrap(pack.message)).is_err() {
                break;
            }
        }
    });
}

#[tokio::main(flavor = "current_thread")]
async fn main() {
    let (outbox, inbox) = unbounded_channel();
    forward::<BootRequest>(&outbox, Command::Boot);
    forward::<EnterRoom>(&outbox, Command::Enter);
    forward::<ChangeBet>(&outbox, Command::Bet);
    forward::<SpinRequest>(&outbox, Command::Spin);
    forward::<WheelSpinRequest>(&outbox, Command::Wheel);
    forward::<RefillRequest>(&outbox, Command::Refill);
    forward::<NotificationsAnswered>(&outbox, Command::Notifications);
    tokio::spawn(engine::run(inbox));
    dart_shutdown().await;
}
